///|
/// Scalar and complex types defined by RFC 7643 section 2.3.
pub(all) enum AttributeType {
  StringType
  BooleanType
  DecimalType
  IntegerType
  DateTimeType
  ReferenceType
  BinaryType
  ComplexType
} derive(Debug, Eq)

///|
pub(all) enum Mutability {
  ReadOnly
  ReadWrite
  Immutable
  WriteOnly
} derive(Debug, Eq)

///|
pub(all) enum Returned {
  Always
  Never
  Default
  Request
} derive(Debug, Eq)

///|
pub(all) enum Uniqueness {
  NoUniqueness
  Server
  Global
} derive(Debug, Eq)

///|
/// Complete declaration of one SCIM attribute.
pub struct AttributeDefinition {
  name : String
  attribute_type : AttributeType
  multi_valued : Bool
  description : String
  required : Bool
  case_exact : Bool
  canonical_values : Array[String]
  mutability : Mutability
  returned : Returned
  uniqueness : Uniqueness
  reference_types : Array[String]
  sub_attributes : Array[AttributeDefinition]
} derive(Debug, Eq)

///|
/// Stable validation finding for schema authoring errors.
pub(all) struct SchemaIssue {
  code : String
  path : String
  message : String
} derive(Debug, Eq)

///|
/// Named SCIM schema identified by a URI.
pub struct Schema {
  id : String
  name : String
  description : String
  attributes : Array[AttributeDefinition]
} derive(Debug, Eq)

///|
pub fn attribute(
  name : String,
  attribute_type : AttributeType,
  multi_valued? : Bool = false,
  description? : String = "",
  required? : Bool = false,
  case_exact? : Bool = false,
  canonical_values? : Array[String] = [],
  mutability? : Mutability = ReadWrite,
  returned? : Returned = Default,
  uniqueness? : Uniqueness = NoUniqueness,
  reference_types? : Array[String] = [],
) -> AttributeDefinition {
  {
    name,
    attribute_type,
    multi_valued,
    description,
    required,
    case_exact,
    canonical_values: canonical_values.copy(),
    mutability,
    returned,
    uniqueness,
    reference_types: reference_types.copy(),
    sub_attributes: [],
  }
}

///|
pub fn complex_attribute(
  name : String,
  sub_attributes : Array[AttributeDefinition],
  multi_valued? : Bool = false,
  description? : String = "",
  required? : Bool = false,
  mutability? : Mutability = ReadWrite,
  returned? : Returned = Default,
) -> AttributeDefinition {
  {
    name,
    attribute_type: ComplexType,
    multi_valued,
    description,
    required,
    case_exact: false,
    canonical_values: [],
    mutability,
    returned,
    uniqueness: NoUniqueness,
    reference_types: [],
    sub_attributes: sub_attributes.copy(),
  }
}

///|
pub fn schema(
  id : String,
  name : String,
  attributes : Array[AttributeDefinition],
  description? : String = "",
) -> Schema {
  { id, name, description, attributes: attributes.copy(), }
}

///|
pub fn AttributeDefinition::name(self : AttributeDefinition) -> String {
  self.name
}

///|
pub fn AttributeDefinition::description(self : AttributeDefinition) -> String {
  self.description
}

///|
pub fn AttributeDefinition::attribute_type(
  self : AttributeDefinition,
) -> AttributeType {
  self.attribute_type
}

///|
pub fn AttributeDefinition::multi_valued(self : AttributeDefinition) -> Bool {
  self.multi_valued
}

///|
pub fn AttributeDefinition::required(self : AttributeDefinition) -> Bool {
  self.required
}

///|
pub fn AttributeDefinition::case_exact(self : AttributeDefinition) -> Bool {
  self.case_exact
}

///|
pub fn AttributeDefinition::mutability(
  self : AttributeDefinition,
) -> Mutability {
  self.mutability
}

///|
pub fn AttributeDefinition::returned(self : AttributeDefinition) -> Returned {
  self.returned
}

///|
pub fn AttributeDefinition::uniqueness(
  self : AttributeDefinition,
) -> Uniqueness {
  self.uniqueness
}

///|
pub fn AttributeDefinition::canonical_values(
  self : AttributeDefinition,
) -> Array[String] {
  self.canonical_values.copy()
}

///|
pub fn AttributeDefinition::reference_types(
  self : AttributeDefinition,
) -> Array[String] {
  self.reference_types.copy()
}

///|
pub fn AttributeDefinition::sub_attributes(
  self : AttributeDefinition,
) -> Array[AttributeDefinition] {
  self.sub_attributes.copy()
}

///|
pub fn Schema::id(self : Schema) -> String {
  self.id
}

///|
pub fn Schema::name(self : Schema) -> String {
  self.name
}

///|
pub fn Schema::description(self : Schema) -> String {
  self.description
}

///|
pub fn Schema::attributes(self : Schema) -> Array[AttributeDefinition] {
  self.attributes.copy()
}

///|
pub fn Schema::attribute(self : Schema, name : String) -> AttributeDefinition? {
  let wanted = name.to_lower()
  for definition in self.attributes {
    if definition.name.to_lower() == wanted {
      return Some(definition)
    }
  }
  None
}

///|
pub fn validate_attribute(
  definition : AttributeDefinition,
) -> Array[SchemaIssue] {
  let issues : Array[SchemaIssue] = []
  if !is_simple_attribute_name(definition.name) {
    issues.push(
      issue(
        "SCHEMA_ATTRIBUTE_NAME",
        definition.name,
        "attribute name must satisfy RFC 7643 ATTRNAME",
      ),
    )
  }
  if definition.attribute_type == ComplexType {
    if definition.sub_attributes.is_empty() {
      issues.push(
        issue(
          "SCHEMA_COMPLEX_EMPTY",
          definition.name,
          "complex attribute must declare at least one sub-attribute",
        ),
      )
    }
    for child in definition.sub_attributes {
      if child.attribute_type == ComplexType || !child.sub_attributes.is_empty() {
        issues.push(
          issue(
            "SCHEMA_COMPLEX_NESTED",
            definition.name + "." + child.name,
            "SCIM complex sub-attributes cannot contain nested sub-attributes",
          ),
        )
      }
    }
  } else if !definition.sub_attributes.is_empty() {
    issues.push(
      issue(
        "SCHEMA_SIMPLE_HAS_CHILDREN",
        definition.name,
        "simple attribute cannot declare sub-attributes",
      ),
    )
  }
  append_duplicate_issues(
    issues,
    definition.sub_attributes,
    definition.name,
    "SCHEMA_SUBATTRIBUTE_DUPLICATE",
  )
  for child in definition.sub_attributes {
    let child_issues = validate_attribute(child)
    for child_issue in child_issues {
      if child_issue.code != "SCHEMA_COMPLEX_NESTED" {
        issues.push(child_issue)
      }
    }
  }
  issues
}

///|
pub fn validate_schema(definition : Schema) -> Array[SchemaIssue] {
  let issues : Array[SchemaIssue] = []
  if !valid_schema_id(definition.id) {
    issues.push(
      issue(
        "SCHEMA_ID", "id", "schema id must be a non-empty URI-like identifier",
      ),
    )
  }
  if definition.name.trim().is_empty() {
    issues.push(issue("SCHEMA_NAME", "name", "schema name must not be empty"))
  }
  append_duplicate_issues(
    issues,
    definition.attributes,
    "attributes",
    "SCHEMA_ATTRIBUTE_DUPLICATE",
  )
  for item in definition.attributes {
    for problem in validate_attribute(item) {
      issues.push(problem)
    }
  }
  issues
}

///|
fn append_duplicate_issues(
  issues : Array[SchemaIssue],
  attributes : Array[AttributeDefinition],
  path : String,
  code : String,
) -> Unit {
  for index, definition in attributes {
    for previous = 0; previous < index; previous = previous + 1 {
      if attributes[previous].name.to_lower() == definition.name.to_lower() {
        issues.push(
          issue(
            code,
            path + "." + definition.name,
            "attribute name is repeated ignoring case",
          ),
        )
        break
      }
    }
  }
}

///|
fn is_simple_attribute_name(value : String) -> Bool {
  match @path.parse_attribute_path(value) {
    Ok(parsed) => parsed.schema_uri is None && parsed.sub_attribute is None
    Err(_) => false
  }
}

///|
fn valid_schema_id(value : String) -> Bool {
  if value.is_empty() || !value.contains(":") {
    return false
  }
  for character in value {
    if character.to_int() <= 32 || character.to_int() >= 127 {
      return false
    }
  }
  true
}

///|
fn issue(code : String, path : String, message : String) -> SchemaIssue {
  { code, path, message, }
}
