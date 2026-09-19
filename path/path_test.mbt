///|
test "parses simple and sub-attribute paths" {
  assert_eq(
    parse_attribute_path("userName"),
    Ok(attribute_path(None, "userName", None)),
  )
  assert_eq(
    parse_attribute_path("name.givenName"),
    Ok(attribute_path(None, "name", Some("givenName"))),
  )
  assert_eq(
    parse_attribute_path("members.$ref"),
    Ok(attribute_path(None, "members", Some("$ref"))),
  )
}

///|
test "parses schema-qualified paths using the final URI colon" {
  let uri = "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
  assert_eq(
    parse_attribute_path(uri + ":employeeNumber"),
    Ok(attribute_path(Some(uri), "employeeNumber", None)),
  )
  assert_eq(
    parse_attribute_path(uri + ":manager.value"),
    Ok(attribute_path(Some(uri), "manager", Some("value"))),
  )
}

///|
test "path equality is case insensitive" {
  let left = parse_attribute_path("Name.GivenName").unwrap()
  let right = parse_attribute_path("name.givenname").unwrap()
  assert_true(left.equivalent(right))
}

///|
test "canonical rendering preserves supplied spelling" {
  let text = "urn:example:params:scim:schemas:custom:2.0:User:costCenter.value"
  assert_eq(parse_attribute_path(text).unwrap().to_string(), text)
}

///|
test "rejects empty malformed and non-ASCII attribute names" {
  assert_true(parse_attribute_path("") is Err(EmptyPath))
  assert_true(parse_attribute_path(".value") is Err(InvalidAttributeName(_)))
  assert_true(parse_attribute_path("name.") is Err(InvalidSubAttributeName(_)))
  assert_true(parse_attribute_path("two.parts.extra") is Err(TooManySegments))
  assert_true(
    parse_attribute_path("display name") is Err(InvalidAttributeName(_)),
  )
  assert_true(parse_attribute_path("名字") is Err(InvalidAttributeName(_)))
  assert_true(parse_attribute_path("urn::userName") is Err(InvalidSchemaUri(_)))
}
