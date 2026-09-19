///|
/// Reasons an SCIM attribute path could not be parsed.
pub(all) enum PathError {
  EmptyPath
  InvalidSchemaUri(String)
  InvalidAttributeName(String)
  InvalidSubAttributeName(String)
  TooManySegments
} derive(Debug, Eq)

///|
/// Parsed RFC 7644 attribute path. The optional schema URI disambiguates
/// extension attributes from core attributes.
pub(all) struct AttributePath {
  schema_uri : String?
  attribute : String
  sub_attribute : String?
} derive(Debug, Eq)

///|
pub fn attribute_path(
  schema_uri : String?,
  attribute : String,
  sub_attribute : String?,
) -> AttributePath {
  { schema_uri, attribute, sub_attribute, }
}

///|
pub fn parse_attribute_path(text : String) -> Result[AttributePath, PathError] {
  if text.is_empty() {
    return Err(EmptyPath)
  }
  let colon = last_character(text, ':')
  let (schema_uri, unqualified) = match colon {
    None => (None, text)
    Some(index) => {
      let schema = text[:index].to_owned()
      if !valid_schema_uri(schema) {
        return Err(InvalidSchemaUri(schema))
      }
      (Some(schema), text[index + 1:].to_owned())
    }
  }
  let mut dot : Int? = None
  for index, character in unqualified {
    if character == '.' {
      if dot is Some(_) {
        return Err(TooManySegments)
      }
      dot = Some(index)
    }
  }
  let (attribute, sub_attribute) = match dot {
    None => (unqualified, None)
    Some(index) =>
      (unqualified[:index].to_owned(), Some(unqualified[index + 1:].to_owned()))
  }
  if !valid_attribute_name(attribute) {
    return Err(InvalidAttributeName(attribute))
  }
  match sub_attribute {
    Some(name) if !valid_attribute_name(name) =>
      Err(InvalidSubAttributeName(name))
    _ => Ok({ schema_uri, attribute, sub_attribute, })
  }
}

///|
pub fn AttributePath::to_string(self : AttributePath) -> String {
  let output = StringBuilder()
  match self.schema_uri {
    Some(uri) => {
      output.write_string(uri)
      output.write_char(':')
    }
    None => ()
  }
  output.write_string(self.attribute)
  match self.sub_attribute {
    Some(name) => {
      output.write_char('.')
      output.write_string(name)
    }
    None => ()
  }
  output.to_string()
}

///|
pub fn AttributePath::equivalent(
  self : AttributePath,
  other : AttributePath,
) -> Bool {
  optional_equal_ignore_case(self.schema_uri, other.schema_uri) &&
  self.attribute.to_lower() == other.attribute.to_lower() &&
  optional_equal_ignore_case(self.sub_attribute, other.sub_attribute)
}

///|
pub fn AttributePath::qualified(self : AttributePath) -> Bool {
  self.schema_uri is Some(_)
}

///|
fn optional_equal_ignore_case(left : String?, right : String?) -> Bool {
  match (left, right) {
    (None, None) => true
    (Some(a), Some(b)) => a.to_lower() == b.to_lower()
    _ => false
  }
}

///|
fn valid_attribute_name(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for index, character in value {
    if index == 0 {
      if !character.is_ascii_alphabetic() {
        return false
      }
    } else if !character.is_ascii_alphabetic() &&
      !character.is_ascii_digit() &&
      character != '$' &&
      character != '-' &&
      character != '_' {
      return false
    }
  }
  true
}

///|
fn valid_schema_uri(value : String) -> Bool {
  if value.is_empty() ||
    value.has_suffix(":") ||
    value.contains("::") ||
    !value.contains(":") {
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
fn last_character(value : String, needle : Char) -> Int? {
  let mut result : Int? = None
  for index, character in value {
    if character == needle {
      result = Some(index)
    }
  }
  result
}
