///|
pub(all) enum BulkPlanError {
  InvalidBulkRequest(BulkIssues)
  UnknownBulkId(Int, String)
  DependencyCycle(Array[String])
} derive(Debug, Eq)

///|
pub struct BulkPlan {
  ordered_operations : Array[BulkOperation]
  source_indices : Array[Int]
} derive(Debug, Eq)

///|
pub(all) struct BulkResolution {
  bulk_id : String
  resource_id : String
} derive(Debug, Eq)

///|
pub(all) enum BulkResolutionError {
  MissingResolution(String)
} derive(Debug, Eq)

///|
pub fn BulkPlan::ordered_operations(self : BulkPlan) -> Array[BulkOperation] {
  self.ordered_operations.copy()
}

///|
pub fn BulkPlan::source_indices(self : BulkPlan) -> Array[Int] {
  self.source_indices.copy()
}

///|
pub fn bulk_resolution(
  bulk_id : String,
  resource_id : String,
) -> BulkResolution {
  { bulk_id, resource_id, }
}

///|
/// Produce a stable topological order for a Bulk Request. Independent
/// operations retain source order; forward bulkId references are supported.
pub fn plan_bulk(request : BulkRequest) -> Result[BulkPlan, BulkPlanError] {
  let issues = validate_bulk_request(request)
  if issues.length() > 0 {
    return Err(InvalidBulkRequest(issues))
  }
  let operations = request.operations()
  let dependencies : Array[Array[Int]] = []
  for index, operation in operations {
    let operation_dependencies : Array[Int] = []
    for reference in operation_references(operation) {
      let dependency = find_bulk_id(operations, reference)
      if dependency < 0 {
        return Err(UnknownBulkId(index, reference))
      }
      if !operation_dependencies.contains(dependency) {
        operation_dependencies.push(dependency)
      }
    }
    dependencies.push(operation_dependencies)
  }
  let scheduled = FixedArray::make(operations.length(), false)
  let ordered : Array[BulkOperation] = []
  let source_indices : Array[Int] = []
  while ordered.length() < operations.length() {
    let mut selected = -1
    for index = 0; index < operations.length(); index = index + 1 {
      if !scheduled[index] &&
        dependencies_satisfied(dependencies[index], scheduled) {
        selected = index
        break
      }
    }
    if selected < 0 {
      let cycle : Array[String] = []
      for index = 0; index < operations.length(); index = index + 1 {
        if !scheduled[index] {
          cycle.push(
            match operations[index].bulk_id() {
              Some(value) => value
              None => "#" + index.to_string()
            },
          )
        }
      }
      return Err(DependencyCycle(cycle))
    }
    scheduled[selected] = true
    ordered.push(operations[selected])
    source_indices.push(selected)
  }
  Ok({ ordered_operations: ordered, source_indices, })
}

///|
pub fn resolve_bulk_operation(
  operation : BulkOperation,
  resolutions : Array[BulkResolution],
) -> Result[BulkOperation, BulkResolutionError] {
  let path = match resolve_text(operation.path(), resolutions) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let data = match operation.data() {
    None => None
    Some(value) =>
      match resolve_value(value, resolutions) {
        Ok(resolved) => Some(resolved)
        Err(error) => return Err(error)
      }
  }
  Ok(
    bulk_operation(
      operation.bulk_method(),
      path,
      bulk_id?=operation.bulk_id(),
      version?=operation.version(),
      data?,
    ),
  )
}

///|
fn dependencies_satisfied(
  dependencies : Array[Int],
  scheduled : FixedArray[Bool],
) -> Bool {
  for dependency in dependencies {
    if !scheduled[dependency] {
      return false
    }
  }
  true
}

///|
fn find_bulk_id(operations : Array[BulkOperation], wanted : String) -> Int {
  let canonical = wanted.to_lower()
  for index, operation in operations {
    match operation.bulk_id() {
      Some(value) if value.to_lower() == canonical => return index
      _ => ()
    }
  }
  -1
}

///|
fn operation_references(operation : BulkOperation) -> Array[String] {
  let result = references_in_text(operation.path())
  match operation.data() {
    Some(value) => append_value_references(result, value)
    None => ()
  }
  result
}

///|
fn append_value_references(
  result : Array[String],
  value : @value.Value,
) -> Unit {
  match value.as_string() {
    Some(text) => append_unique(result, references_in_text(text))
    None => ()
  }
  match value.as_list() {
    Some(items) =>
      for item in items {
        append_value_references(result, item)
      }
    None => ()
  }
  match value.as_object() {
    Some(object) =>
      for entry in object.entries() {
        append_value_references(result, entry.value())
      }
    None => ()
  }
}

///|
fn references_in_text(text : String) -> Array[String] {
  let result : Array[String] = []
  let fragments = text.split("bulkId:").map(part => part.to_owned()).collect()
  for index = 1; index < fragments.length(); index = index + 1 {
    let fragment = fragments[index]
    let output = StringBuilder()
    for character in fragment {
      if reference_character(character) {
        output.write_char(character)
      } else {
        break
      }
    }
    let reference = output.to_string()
    if !reference.is_empty() && !contains_ignore_case(result, reference) {
      result.push(reference)
    }
  }
  result
}

///|
fn reference_character(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '-' ||
  character == '_' ||
  character == '.'
}

///|
fn contains_ignore_case(values : Array[String], value : String) -> Bool {
  let wanted = value.to_lower()
  for candidate in values {
    if candidate.to_lower() == wanted {
      return true
    }
  }
  false
}

///|
fn append_unique(target : Array[String], additions : Array[String]) -> Unit {
  for value in additions {
    if !contains_ignore_case(target, value) {
      target.push(value)
    }
  }
}

///|
fn resolve_text(
  text : String,
  resolutions : Array[BulkResolution],
) -> Result[String, BulkResolutionError] {
  let mut result = text
  for reference in references_in_text(text) {
    guard find_resolution(resolutions, reference) is Some(resource_id) else {
      return Err(MissingResolution(reference))
    }
    result = result.replace(old="bulkId:" + reference, new=resource_id)
  }
  Ok(result)
}

///|
fn find_resolution(
  resolutions : Array[BulkResolution],
  wanted : String,
) -> String? {
  let canonical = wanted.to_lower()
  for resolution in resolutions {
    if resolution.bulk_id.to_lower() == canonical {
      return Some(resolution.resource_id)
    }
  }
  None
}

///|
fn resolve_value(
  value : @value.Value,
  resolutions : Array[BulkResolution],
) -> Result[@value.Value, BulkResolutionError] {
  match value.as_string() {
    Some(text) =>
      match resolve_text(text, resolutions) {
        Ok(resolved) => return Ok(@value.string(resolved))
        Err(error) => return Err(error)
      }
    None => ()
  }
  match value.as_list() {
    Some(items) => {
      let resolved : Array[@value.Value] = []
      for item in items {
        match resolve_value(item, resolutions) {
          Ok(result) => resolved.push(result)
          Err(error) => return Err(error)
        }
      }
      return Ok(@value.list(resolved))
    }
    None => ()
  }
  match value.as_object() {
    Some(object) => {
      let fields : Array[@value.Field] = []
      for entry in object.entries() {
        match resolve_value(entry.value(), resolutions) {
          Ok(result) => fields.push(@value.field(entry.name(), result))
          Err(error) => return Err(error)
        }
      }
      return Ok(@value.object_value(fields))
    }
    None => ()
  }
  Ok(value)
}
