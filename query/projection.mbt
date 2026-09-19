///|
pub(all) enum ProjectionError {
  ConflictingProjection
  InvalidProjectionPath(String, @path.PathError)
} derive(Debug, Eq)

///|
/// Apply SCIM `attributes` or `excludedAttributes` selection. The two modes
/// are mutually exclusive, matching RFC 7644 query semantics.
pub fn project_attributes(
  resource : @value.Object,
  attributes : Array[String],
  excluded_attributes : Array[String],
) -> Result[@value.Object, ProjectionError] {
  if !attributes.is_empty() && !excluded_attributes.is_empty() {
    return Err(ConflictingProjection)
  }
  let parsed = match
    parse_paths(
      if attributes.is_empty() {
        excluded_attributes
      } else {
        attributes
      },
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if attributes.is_empty() {
    let mut result = resource
    for path in parsed {
      result = exclude_path(result, path)
    }
    Ok(result)
  } else {
    let mut result = @value.object([])
    for common in ["schemas", "id", "meta"] {
      match resource.get(common) {
        Some(value) => result = result.put(common, value)
        None => ()
      }
    }
    for path in parsed {
      result = include_path(result, resource, path)
    }
    Ok(result)
  }
}

///|
fn parse_paths(
  values : Array[String],
) -> Result[Array[@path.AttributePath], ProjectionError] {
  let result : Array[@path.AttributePath] = []
  for text in values {
    match @path.parse_attribute_path(text) {
      Ok(value) => result.push(value)
      Err(error) => return Err(InvalidProjectionPath(text, error))
    }
  }
  Ok(result)
}

///|
fn include_path(
  target : @value.Object,
  source : @value.Object,
  path : @path.AttributePath,
) -> @value.Object {
  match path.schema_uri {
    None => include_in_object(target, source, path)
    Some(uri) => {
      guard source.get(uri) is Some(raw_extension) else { return target }
      guard raw_extension.as_object() is Some(source_extension) else {
        return target
      }
      let target_extension = match target.get(uri) {
        Some(value) => value.as_object().unwrap_or(@value.object([]))
        None => @value.object([])
      }
      let unqualified = @path.attribute_path(
        None,
        path.attribute,
        path.sub_attribute,
      )
      let updated = include_in_object(
        target_extension, source_extension, unqualified,
      )
      if updated.is_empty() {
        target
      } else {
        target.put(uri, @value.object_value(updated.entries()))
      }
    }
  }
}

///|
fn include_in_object(
  target : @value.Object,
  source : @value.Object,
  path : @path.AttributePath,
) -> @value.Object {
  guard source.get(path.attribute) is Some(value) else { return target }
  match path.sub_attribute {
    None => target.put(path.attribute, value)
    Some(child) => {
      guard value.as_object() is Some(source_parent) else { return target }
      guard source_parent.get(child) is Some(child_value) else { return target }
      let target_parent = match target.get(path.attribute) {
        Some(existing) => existing.as_object().unwrap_or(@value.object([]))
        None => @value.object([])
      }
      let updated_parent = target_parent.put(child, child_value)
      target.put(path.attribute, @value.object_value(updated_parent.entries()))
    }
  }
}

///|
fn exclude_path(
  resource : @value.Object,
  path : @path.AttributePath,
) -> @value.Object {
  match path.schema_uri {
    None => exclude_in_object(resource, path)
    Some(uri) => {
      guard resource.get(uri) is Some(value) else { return resource }
      guard value.as_object() is Some(extension) else { return resource }
      let unqualified = @path.attribute_path(
        None,
        path.attribute,
        path.sub_attribute,
      )
      let updated = exclude_in_object(extension, unqualified)
      resource.put(uri, @value.object_value(updated.entries()))
    }
  }
}

///|
fn exclude_in_object(
  object : @value.Object,
  path : @path.AttributePath,
) -> @value.Object {
  match path.sub_attribute {
    None => object.remove(path.attribute)
    Some(child) => {
      guard object.get(path.attribute) is Some(value) else { return object }
      guard value.as_object() is Some(parent) else { return object }
      let updated = parent.remove(child)
      object.put(path.attribute, @value.object_value(updated.entries()))
    }
  }
}
