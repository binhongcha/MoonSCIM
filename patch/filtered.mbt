///|
priv struct FilteredPatchPath {
  base : @path.AttributePath
  filter : @filter.Filter
  sub_attribute : String?
}

///|
fn apply_filtered_operation(
  resource : @value.Object,
  operation : PatchOperation,
  index : Int,
) -> Result[@value.Object, PatchError] {
  let parsed = match parse_filtered_patch_path(operation.path) {
    Ok(value) => value
    Err(message) => return Err(InvalidFilteredPath(index, message))
  }
  let (container, extension_uri) = match parsed.base.schema_uri {
    None => (resource, None)
    Some(uri) =>
      match resource.get(uri) {
        Some(value) =>
          match value.as_object() {
            Some(object) => (object, Some(uri))
            None => return Err(TargetType(index, uri))
          }
        None => return Err(TargetMissing(index, uri))
      }
  }
  guard container.get(parsed.base.attribute) is Some(raw) else {
    return Err(TargetMissing(index, parsed.base.to_string()))
  }
  guard raw.as_list() is Some(items) else {
    return Err(TargetType(index, parsed.base.to_string()))
  }
  let updated : Array[@value.Value] = []
  let mut matched = false
  for item in items {
    guard item.as_object() is Some(object) else {
      updated.push(item)
      continue
    }
    if !parsed.filter.matches(object) {
      updated.push(item)
      continue
    }
    matched = true
    match parsed.sub_attribute {
      Some(name) => {
        let child = raw_operation(operation.verb, name, operation.value)
        match apply_top_level(object, child, name, index) {
          Ok(result) => updated.push(@value.object_value(result.entries()))
          Err(error) => return Err(error)
        }
      }
      None =>
        match operation.verb {
          Remove => ()
          Replace =>
            match operation.value {
              Some(value) => updated.push(value)
              None => return Err(MissingValue(index))
            }
          Add =>
            match operation.value {
              Some(value) =>
                match value.as_object() {
                  Some(additions) => {
                    let mut merged = object
                    for entry in additions.entries() {
                      merged = merged.put(entry.name(), entry.value())
                    }
                    updated.push(@value.object_value(merged.entries()))
                  }
                  None => return Err(TargetType(index, operation.path))
                }
              None => return Err(MissingValue(index))
            }
        }
    }
  }
  if !matched {
    return Err(TargetMissing(index, operation.path))
  }
  let updated_container = container.put(
    parsed.base.attribute,
    @value.list(updated),
  )
  match extension_uri {
    None => Ok(updated_container)
    Some(uri) =>
      Ok(resource.put(uri, @value.object_value(updated_container.entries())))
  }
}

///|
fn parse_filtered_patch_path(
  text : String,
) -> Result[FilteredPatchPath, String] {
  let mut open : Int? = None
  let mut close : Int? = None
  let mut quoted = false
  let mut escaped = false
  for index, character in text {
    if escaped {
      escaped = false
    } else if quoted && character == '\\' {
      escaped = true
    } else if character == '"' {
      quoted = !quoted
    } else if !quoted && character == '[' && open is None {
      open = Some(index)
    } else if !quoted && character == ']' {
      close = Some(index)
    }
  }
  guard open is Some(open_index) else { return Err("missing '['") }
  guard close is Some(close_index) else { return Err("missing ']'") }
  if close_index <= open_index + 1 {
    return Err("value filter is empty")
  }
  let base_text = text[:open_index].to_owned()
  let base = match @path.parse_attribute_path(base_text) {
    Ok(value) => value
    Err(_) => return Err("invalid base attribute path")
  }
  if base.sub_attribute is Some(_) {
    return Err("value filter base cannot contain a sub-attribute")
  }
  let predicate_text = text[open_index + 1:close_index].to_owned()
  let filter = match @filter.compile_filter(predicate_text) {
    Ok(value) => value
    Err(_) => return Err("invalid value filter")
  }
  let suffix = text[close_index + 1:].to_owned()
  let sub_attribute = if suffix.is_empty() {
    None
  } else if suffix.has_prefix(".") && suffix.length() > 1 {
    let name = suffix[1:].to_owned()
    match @path.parse_attribute_path(name) {
      Ok(parsed) if parsed.schema_uri is None && parsed.sub_attribute is None =>
        Some(name)
      _ => return Err("invalid trailing sub-attribute")
    }
  } else {
    return Err("expected '.subAttribute' after value filter")
  }
  Ok({ base, filter, sub_attribute, })
}
