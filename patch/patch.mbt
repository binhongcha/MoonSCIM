///|
pub(all) enum PatchVerb {
  Add
  Replace
  Remove
} derive(Debug, Eq)

///|
pub struct PatchOperation {
  verb : PatchVerb
  path : String
  value : @value.Value?
} derive(Debug, Eq)

///|
pub(all) enum PatchError {
  MissingValue(Int)
  InvalidPatchPath(Int, @path.PathError)
  TargetMissing(Int, String)
  TargetType(Int, String)
} derive(Debug, Eq)

///|
pub fn raw_operation(
  verb : PatchVerb,
  path : String,
  value : @value.Value?,
) -> PatchOperation {
  { verb, path, value, }
}

///|
pub fn add(path : String, value : @value.Value) -> PatchOperation {
  { verb: Add, path, value: Some(value), }
}

///|
pub fn replace(path : String, value : @value.Value) -> PatchOperation {
  { verb: Replace, path, value: Some(value), }
}

///|
pub fn remove(path : String) -> PatchOperation {
  { verb: Remove, path, value: None, }
}

///|
/// Apply operations in order to an immutable Object snapshot. No partially
/// updated Object is returned when any operation fails.
pub fn apply_patch(
  resource : @value.Object,
  operations : Array[PatchOperation],
) -> Result[@value.Object, PatchError] {
  let mut current = resource
  for index, operation in operations {
    if operation.verb != Remove && operation.value is None {
      return Err(MissingValue(index))
    }
    let path = match @path.parse_attribute_path(operation.path) {
      Ok(value) => value
      Err(error) => return Err(InvalidPatchPath(index, error))
    }
    current = match apply_one(current, operation, path, index) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  }
  Ok(current)
}

///|
fn apply_one(
  resource : @value.Object,
  operation : PatchOperation,
  path : @path.AttributePath,
  index : Int,
) -> Result[@value.Object, PatchError] {
  match path.schema_uri {
    None => apply_in_object(resource, operation, path, index)
    Some(uri) => {
      let extension = match resource.get(uri) {
        Some(value) =>
          match value.as_object() {
            Some(object) => object
            None => return Err(TargetType(index, uri))
          }
        None =>
          if operation.verb == Add {
            @value.object([])
          } else {
            return Err(TargetMissing(index, uri))
          }
      }
      let inner_path = @path.attribute_path(
        None,
        path.attribute,
        path.sub_attribute,
      )
      match apply_in_object(extension, operation, inner_path, index) {
        Ok(updated) =>
          Ok(resource.put(uri, @value.object_value(updated.entries())))
        Err(error) => Err(error)
      }
    }
  }
}

///|
fn apply_in_object(
  object : @value.Object,
  operation : PatchOperation,
  path : @path.AttributePath,
  index : Int,
) -> Result[@value.Object, PatchError] {
  match path.sub_attribute {
    None => apply_top_level(object, operation, path.attribute, index)
    Some(child_name) => {
      guard object.get(path.attribute) is Some(parent_value) else {
        return Err(TargetMissing(index, path.to_string()))
      }
      guard parent_value.as_object() is Some(parent) else {
        return Err(TargetType(index, path.attribute))
      }
      let child_operation = raw_operation(
        operation.verb,
        child_name,
        operation.value,
      )
      match apply_top_level(parent, child_operation, child_name, index) {
        Ok(updated_parent) =>
          Ok(
            object.put(
              path.attribute,
              @value.object_value(updated_parent.entries()),
            ),
          )
        Err(error) => Err(error)
      }
    }
  }
}

///|
fn apply_top_level(
  object : @value.Object,
  operation : PatchOperation,
  name : String,
  index : Int,
) -> Result[@value.Object, PatchError] {
  match operation.verb {
    Remove =>
      if object.contains(name) {
        Ok(object.remove(name))
      } else {
        Err(TargetMissing(index, name))
      }
    Replace =>
      if object.contains(name) {
        match operation.value {
          Some(value) => Ok(object.put(name, value))
          None => Err(MissingValue(index))
        }
      } else {
        Err(TargetMissing(index, name))
      }
    Add =>
      match operation.value {
        None => Err(MissingValue(index))
        Some(incoming) =>
          match object.get(name) {
            Some(existing) =>
              match existing.as_list() {
                Some(items) => {
                  let combined = items.copy()
                  match incoming.as_list() {
                    Some(additions) =>
                      for item in additions {
                        combined.push(item)
                      }
                    None => combined.push(incoming)
                  }
                  Ok(object.put(name, @value.list(combined)))
                }
                None => Ok(object.put(name, incoming))
              }
            None => Ok(object.put(name, incoming))
          }
      }
  }
}
