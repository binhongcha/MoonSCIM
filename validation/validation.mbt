///|
/// Operation context in which a resource is validated.
pub(all) enum ValidationOperation {
  Create
  Replace
  Patch
  Response
} derive(Debug, Eq)

///|
pub(all) struct Diagnostic {
  code : String
  path : String
  message : String
} derive(Debug, Eq)

///|
pub struct ValidationReport {
  operation : ValidationOperation
  diagnostics : Array[Diagnostic]
} derive(Debug, Eq)

///|
pub fn ValidationReport::operation(
  self : ValidationReport,
) -> ValidationOperation {
  self.operation
}

///|
pub fn ValidationReport::is_valid(self : ValidationReport) -> Bool {
  self.diagnostics.is_empty()
}

///|
pub fn ValidationReport::diagnostics(
  self : ValidationReport,
) -> Array[Diagnostic] {
  self.diagnostics.copy()
}

///|
pub fn ValidationReport::has_code(
  self : ValidationReport,
  code : String,
) -> Bool {
  for item in self.diagnostics {
    if item.code == code {
      return true
    }
  }
  false
}

///|
/// Validate a Resource against its base schema and any registered extension
/// containers. The function has no storage or uniqueness side effects.
pub fn validate_resource(
  registry : @schema.SchemaRegistry,
  base_schema_id : String,
  resource : @value.Object,
  operation : ValidationOperation,
) -> ValidationReport {
  let diagnostics : Array[Diagnostic] = []
  guard registry.find(base_schema_id) is Some(base_schema) else {
    diagnostics.push(
      diagnostic(
        "RESOURCE_SCHEMA_UNKNOWN",
        "schemas",
        "base schema is not registered: " + base_schema_id,
      ),
    )
    return { operation, diagnostics, }
  }
  validate_schemas_attribute(
    registry,
    base_schema_id,
    resource.get("schemas"),
    diagnostics,
  )
  validate_object_against_schema(
    registry, base_schema, resource, "", true, operation, diagnostics,
  )
  { operation, diagnostics, }
}

///|
/// Validate an updated resource and compare immutable values with their prior
/// assigned state. Immutable values may be assigned once but not changed or
/// removed afterwards.
pub fn validate_transition(
  registry : @schema.SchemaRegistry,
  base_schema_id : String,
  before : @value.Object,
  after : @value.Object,
  operation : ValidationOperation,
) -> ValidationReport {
  let report = validate_resource(registry, base_schema_id, after, operation)
  let diagnostics = report.diagnostics()
  match registry.find(base_schema_id) {
    Some(definition) =>
      validate_immutable_attributes(
        definition.attributes(),
        before,
        after,
        "",
        diagnostics,
      )
    None => ()
  }
  { operation, diagnostics, }
}

///|
fn validate_immutable_attributes(
  definitions : Array[@schema.AttributeDefinition],
  before : @value.Object,
  after : @value.Object,
  prefix : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  for definition in definitions {
    let path = join_path(prefix, definition.name())
    let old_value = before.get(definition.name())
    let new_value = after.get(definition.name())
    if definition.mutability() == @schema.Immutable &&
      assigned(old_value) &&
      old_value != new_value {
      diagnostics.push(
        diagnostic(
          "RESOURCE_IMMUTABLE", path, "an assigned immutable attribute cannot be changed or removed",
        ),
      )
    }
    if definition.attribute_type() == @schema.ComplexType &&
      !definition.multi_valued() {
      match (old_value, new_value) {
        (Some(old), Some(new)) =>
          match (old.as_object(), new.as_object()) {
            (Some(old_object), Some(new_object)) =>
              validate_immutable_attributes(
                definition.sub_attributes(),
                old_object,
                new_object,
                path,
                diagnostics,
              )
            _ => ()
          }
        _ => ()
      }
    }
  }
}

///|
fn validate_schemas_attribute(
  registry : @schema.SchemaRegistry,
  base_schema_id : String,
  schemas_value : @value.Value?,
  diagnostics : Array[Diagnostic],
) -> Unit {
  guard schemas_value is Some(value) else {
    diagnostics.push(
      diagnostic(
        "RESOURCE_SCHEMAS_REQUIRED", "schemas", "resource must declare its schemas",
      ),
    )
    return
  }
  guard value.as_list() is Some(items) else {
    diagnostics.push(
      diagnostic(
        "RESOURCE_SCHEMAS_TYPE", "schemas", "schemas must be a multi-valued string attribute",
      ),
    )
    return
  }
  let mut found_base = false
  let seen : Array[String] = []
  for index, item in items {
    guard item.as_string() is Some(schema_id) else {
      diagnostics.push(
        diagnostic(
          "RESOURCE_SCHEMAS_ITEM_TYPE",
          "schemas[" + index.to_string() + "]",
          "schema identifiers must be strings",
        ),
      )
      continue
    }
    let canonical = schema_id.to_lower()
    if seen.contains(canonical) {
      diagnostics.push(
        diagnostic(
          "RESOURCE_SCHEMAS_DUPLICATE",
          "schemas[" + index.to_string() + "]",
          "schema identifier is repeated ignoring case",
        ),
      )
    } else {
      seen.push(canonical)
    }
    if canonical == base_schema_id.to_lower() {
      found_base = true
    }
    if registry.find(schema_id) is None {
      diagnostics.push(
        diagnostic(
          "RESOURCE_SCHEMA_UNKNOWN",
          "schemas[" + index.to_string() + "]",
          "schema is not registered: " + schema_id,
        ),
      )
    }
  }
  if !found_base {
    diagnostics.push(
      diagnostic(
        "RESOURCE_BASE_SCHEMA_MISSING", "schemas", "schemas does not contain the resource type's base schema",
      ),
    )
  }
}

///|
fn validate_object_against_schema(
  registry : @schema.SchemaRegistry,
  definition : @schema.Schema,
  object : @value.Object,
  prefix : String,
  allow_common : Bool,
  operation : ValidationOperation,
  diagnostics : Array[Diagnostic],
) -> Unit {
  for attribute in definition.attributes() {
    let path = join_path(prefix, attribute.name())
    let actual = object.get(attribute.name())
    if attribute.required() && !assigned(actual) {
      diagnostics.push(
        diagnostic(
          "RESOURCE_REQUIRED", path, "required attribute is unassigned",
        ),
      )
    }
    if assigned(actual) &&
      operation != Response &&
      attribute.mutability() == @schema.ReadOnly {
      diagnostics.push(
        diagnostic(
          "RESOURCE_READ_ONLY", path, "read-only attribute cannot be supplied by a protocol write",
        ),
      )
    }
    if assigned(actual) &&
      operation == Response &&
      attribute.mutability() == @schema.WriteOnly {
      diagnostics.push(
        diagnostic(
          "RESOURCE_WRITE_ONLY", path, "write-only attribute cannot appear in a response resource",
        ),
      )
    }
    match actual {
      Some(value) if !value.is_null() =>
        validate_attribute_value(attribute, value, path, diagnostics)
      _ => ()
    }
  }
  for item in object.entries() {
    let name = item.name()
    if definition.attribute(name) is Some(_) ||
      (allow_common && common_name(name)) {
      continue
    }
    match registry.find(name) {
      Some(extension) =>
        match item.value().as_object() {
          Some(extension_object) =>
            validate_object_against_schema(
              registry, extension, extension_object, name, false, operation, diagnostics,
            )
          None =>
            diagnostics.push(
              diagnostic(
                "RESOURCE_EXTENSION_TYPE", name, "schema extension container must be an object",
              ),
            )
        }
      None =>
        diagnostics.push(
          diagnostic(
            "RESOURCE_UNKNOWN_ATTRIBUTE",
            join_path(prefix, name),
            "attribute is not declared by the active schema",
          ),
        )
    }
  }
}

///|
fn validate_attribute_value(
  definition : @schema.AttributeDefinition,
  value : @value.Value,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if definition.multi_valued() {
    guard value.as_list() is Some(items) else {
      diagnostics.push(
        diagnostic(
          "RESOURCE_CARDINALITY", path, "multi-valued attribute must be represented as a list",
        ),
      )
      return
    }
    for index, item in items {
      validate_single_value(
        definition,
        item,
        path + "[" + index.to_string() + "]",
        diagnostics,
      )
    }
  } else {
    validate_single_value(definition, value, path, diagnostics)
  }
}

///|
fn validate_single_value(
  definition : @schema.AttributeDefinition,
  value : @value.Value,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if value.is_null() {
    return
  }
  let expected = definition.attribute_type()
  let actual = value.kind()
  let type_matches = match expected {
    @schema.StringType
    | @schema.DateTimeType
    | @schema.ReferenceType
    | @schema.BinaryType => actual == @value.String
    @schema.BooleanType => actual == @value.Boolean
    @schema.DecimalType | @schema.IntegerType => actual == @value.Number
    @schema.ComplexType => actual == @value.Object
  }
  if !type_matches {
    diagnostics.push(
      diagnostic(
        "RESOURCE_TYPE", path, "attribute value does not match its declared SCIM type",
      ),
    )
    return
  }
  if expected == @schema.ComplexType {
    guard value.as_object() is Some(object) else { return }
    validate_complex(definition, object, path, diagnostics)
  } else {
    validate_canonical(definition, value, path, diagnostics)
  }
}

///|
fn validate_complex(
  definition : @schema.AttributeDefinition,
  object : @value.Object,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let children = definition.sub_attributes()
  for child in children {
    let child_path = path + "." + child.name()
    let actual = object.get(child.name())
    if child.required() && !assigned(actual) {
      diagnostics.push(
        diagnostic(
          "RESOURCE_REQUIRED", child_path, "required sub-attribute is unassigned",
        ),
      )
    }
    match actual {
      Some(value) if !value.is_null() =>
        validate_attribute_value(child, value, child_path, diagnostics)
      _ => ()
    }
  }
  for item in object.entries() {
    let mut known = false
    for child in children {
      if child.name().to_lower() == item.name().to_lower() {
        known = true
        break
      }
    }
    if !known {
      diagnostics.push(
        diagnostic(
          "RESOURCE_UNKNOWN_ATTRIBUTE",
          path + "." + item.name(),
          "complex value contains an undeclared sub-attribute",
        ),
      )
    }
  }
}

///|
fn validate_canonical(
  definition : @schema.AttributeDefinition,
  value : @value.Value,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let allowed = definition.canonical_values()
  if allowed.is_empty() {
    return
  }
  guard value.as_string() is Some(text) else { return }
  for candidate in allowed {
    if (definition.case_exact() && candidate == text) ||
      (!definition.case_exact() && candidate.to_lower() == text.to_lower()) {
      return
    }
  }
  diagnostics.push(
    diagnostic(
      "RESOURCE_CANONICAL", path, "string value is not one of the declared canonical values",
    ),
  )
}

///|
fn assigned(value : @value.Value?) -> Bool {
  match value {
    None => false
    Some(item) if item.is_null() => false
    Some(item) =>
      match item.as_list() {
        Some(items) => !items.is_empty()
        None => true
      }
  }
}

///|
fn common_name(name : String) -> Bool {
  match name.to_lower() {
    "schemas" | "id" | "externalid" | "meta" => true
    _ => false
  }
}

///|
fn join_path(prefix : String, name : String) -> String {
  if prefix.is_empty() {
    name
  } else {
    prefix + "." + name
  }
}

///|
fn diagnostic(code : String, path : String, message : String) -> Diagnostic {
  { code, path, message, }
}
