///|
test "builds valid simple and complex attribute definitions" {
  let given = attribute("givenName", StringType)
  let family = attribute("familyName", StringType)
  let name = complex_attribute("name", [given, family])
  assert_eq(validate_attribute(given), [])
  assert_eq(validate_attribute(name), [])
  assert_eq(name.sub_attributes().length(), 2)
}

///|
test "attribute metadata captures SCIM characteristics" {
  let username = attribute(
    "userName",
    StringType,
    required=true,
    case_exact=false,
    mutability=ReadWrite,
    returned=Always,
    uniqueness=Server,
  )
  assert_true(username.required())
  assert_false(username.case_exact())
  assert_eq(username.mutability(), ReadWrite)
  assert_eq(username.returned(), Always)
  assert_eq(username.uniqueness(), Server)
}

///|
test "rejects malformed attribute definitions" {
  let bad_name = attribute("display name", StringType)
  assert_true(validate_attribute(bad_name)[0].code == "SCHEMA_ATTRIBUTE_NAME")
  let empty_complex = complex_attribute("name", [])
  assert_true(
    validate_attribute(empty_complex)[0].code == "SCHEMA_COMPLEX_EMPTY",
  )
  let nested = complex_attribute("outer", [
    complex_attribute("inner", [attribute("value", StringType)]),
  ])
  assert_true(validate_attribute(nested)[0].code == "SCHEMA_COMPLEX_NESTED")
}

///|
test "rejects duplicate sub-attributes ignoring case" {
  let duplicate = complex_attribute(
    "emails",
    [attribute("value", StringType), attribute("VALUE", StringType)],
    multi_valued=true,
  )
  let issues = validate_attribute(duplicate)
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].code, "SCHEMA_SUBATTRIBUTE_DUPLICATE")
}

///|
test "schema validation rejects duplicate top-level attributes" {
  let definition = schema("urn:example:schemas:2.0:Account", "Account", [
    attribute("displayName", StringType),
    attribute("DISPLAYNAME", StringType),
  ])
  let issues = validate_schema(definition)
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].code, "SCHEMA_ATTRIBUTE_DUPLICATE")
}
