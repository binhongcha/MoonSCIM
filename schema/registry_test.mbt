///|
fn account_schema() -> Schema {
  schema("urn:example:schemas:2.0:Account", "Account", [
    attribute("userName", StringType, required=true),
    complex_attribute("name", [
      attribute("givenName", StringType),
      attribute("familyName", StringType),
    ]),
  ])
}

///|
test "registry finds schema identifiers case insensitively" {
  let registry = schema_registry().register(account_schema()).unwrap()
  assert_true(registry.find("URN:EXAMPLE:SCHEMAS:2.0:ACCOUNT") is Some(_))
  assert_eq(registry.length(), 1)
}

///|
test "registry rejects duplicate schema identifiers" {
  let registry = schema_registry().register(account_schema()).unwrap()
  assert_true(registry.register(account_schema()) is Err(DuplicateSchema(_)))
}

///|
test "registry resolves unqualified and qualified attribute paths" {
  let registry = schema_registry().register(account_schema()).unwrap()
  let base = "urn:example:schemas:2.0:Account"
  let username = @path.parse_attribute_path("userName").unwrap()
  let family = @path.parse_attribute_path(base + ":name.familyName").unwrap()
  assert_eq(
    registry.resolve(base, username).unwrap().attribute().name(),
    "userName",
  )
  assert_eq(
    registry.resolve(base, family).unwrap().sub_attribute().unwrap().name(),
    "familyName",
  )
}

///|
test "registry returns structured lookup failures" {
  let registry = schema_registry().register(account_schema()).unwrap()
  let base = "urn:example:schemas:2.0:Account"
  assert_true(
    registry.resolve(base, @path.parse_attribute_path("missing").unwrap())
    is Err(UnknownAttribute(_, _)),
  )
  assert_true(
    registry.resolve(base, @path.parse_attribute_path("name.missing").unwrap())
    is Err(UnknownSubAttribute(_, _, _)),
  )
  assert_true(
    registry.resolve(
      "urn:missing",
      @path.parse_attribute_path("userName").unwrap(),
    )
    is Err(UnknownSchema(_)),
  )
}
