///|
pub(all) enum RegistryError {
  InvalidSchema(String, Array[SchemaIssue])
  DuplicateSchema(String)
  UnknownSchema(String)
  UnknownAttribute(String, String)
  UnknownSubAttribute(String, String, String)
} derive(Debug, Eq)

///|
/// Result of resolving an Attribute Path against registered schemas.
pub struct ResolvedAttribute {
  schema_id : String
  attribute : AttributeDefinition
  sub_attribute : AttributeDefinition?
} derive(Debug, Eq)

///|
/// Immutable collection of schemas used by validation, filters, PATCH, and
/// projection. URI lookup follows SCIM's case-insensitive comparison rules.
pub struct SchemaRegistry {
  schemas : Array[Schema]
} derive(Debug, Eq)

///|
pub fn schema_registry() -> SchemaRegistry {
  { schemas: [], }
}

///|
pub fn SchemaRegistry::length(self : SchemaRegistry) -> Int {
  self.schemas.length()
}

///|
pub fn SchemaRegistry::schemas(self : SchemaRegistry) -> Array[Schema] {
  self.schemas.copy()
}

///|
pub fn SchemaRegistry::find(self : SchemaRegistry, id : String) -> Schema? {
  let wanted = id.to_lower()
  for definition in self.schemas {
    if definition.id().to_lower() == wanted {
      return Some(definition)
    }
  }
  None
}

///|
/// Validate and add a schema, returning a new registry.
pub fn SchemaRegistry::register(
  self : SchemaRegistry,
  definition : Schema,
) -> Result[SchemaRegistry, RegistryError] {
  let issues = validate_schema(definition)
  if !issues.is_empty() {
    return Err(InvalidSchema(definition.id(), issues))
  }
  if self.find(definition.id()) is Some(_) {
    return Err(DuplicateSchema(definition.id()))
  }
  let schemas = self.schemas.copy()
  schemas.push(definition)
  Ok({ schemas, })
}

///|
/// Resolve a parsed path. Unqualified paths use `base_schema_id`; qualified
/// paths select their schema explicitly.
pub fn SchemaRegistry::resolve(
  self : SchemaRegistry,
  base_schema_id : String,
  path : @path.AttributePath,
) -> Result[ResolvedAttribute, RegistryError] {
  let schema_id = match path.schema_uri {
    Some(value) => value
    None => base_schema_id
  }
  guard self.find(schema_id) is Some(definition) else {
    return Err(UnknownSchema(schema_id))
  }
  guard definition.attribute(path.attribute) is Some(attribute) else {
    return Err(UnknownAttribute(schema_id, path.attribute))
  }
  let sub_attribute = match path.sub_attribute {
    None => None
    Some(name) => {
      guard find_sub_attribute(attribute, name) is Some(child) else {
        return Err(UnknownSubAttribute(schema_id, attribute.name(), name))
      }
      Some(child)
    }
  }
  Ok({ schema_id: definition.id(), attribute, sub_attribute, })
}

///|
pub fn ResolvedAttribute::schema_id(self : ResolvedAttribute) -> String {
  self.schema_id
}

///|
pub fn ResolvedAttribute::attribute(
  self : ResolvedAttribute,
) -> AttributeDefinition {
  self.attribute
}

///|
pub fn ResolvedAttribute::sub_attribute(
  self : ResolvedAttribute,
) -> AttributeDefinition? {
  self.sub_attribute
}

///|
pub fn ResolvedAttribute::leaf(self : ResolvedAttribute) -> AttributeDefinition {
  match self.sub_attribute {
    Some(value) => value
    None => self.attribute
  }
}

///|
fn find_sub_attribute(
  definition : AttributeDefinition,
  name : String,
) -> AttributeDefinition? {
  let wanted = name.to_lower()
  for child in definition.sub_attributes() {
    if child.name().to_lower() == wanted {
      return Some(child)
    }
  }
  None
}
