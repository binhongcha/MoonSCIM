///|
fn projection_user() -> @value.Object {
  @value.object([
    @value.field("schemas", @value.list([@value.string("urn:user")])),
    @value.field("id", @value.string("u-1")),
    @value.field("userName", @value.string("alice")),
    @value.field("active", @value.boolean(true)),
    @value.field(
      "name",
      @value.object_value([
        @value.field("givenName", @value.string("Alice")),
        @value.field("familyName", @value.string("Example")),
      ]),
    ),
  ])
}

///|
test "inclusive projection keeps common metadata and selected leaves" {
  let projected = project_attributes(
    projection_user(),
    ["userName", "name.givenName"],
    [],
  ).unwrap()
  assert_true(projected.contains("schemas"))
  assert_true(projected.contains("id"))
  assert_true(projected.contains("userName"))
  assert_false(projected.contains("active"))
  let name = projected.get("name").unwrap().as_object().unwrap()
  assert_true(name.contains("givenName"))
  assert_false(name.contains("familyName"))
}

///|
test "exclusive projection removes attributes and complex leaves" {
  let projected = project_attributes(projection_user(), [], [
    "active", "name.familyName",
  ]).unwrap()
  assert_false(projected.contains("active"))
  assert_eq(
    projected.get("name").unwrap().as_object().unwrap().get("givenName"),
    Some(@value.string("Alice")),
  )
  assert_eq(
    projected.get("name").unwrap().as_object().unwrap().get("familyName"),
    None,
  )
}

///|
test "projection handles schema extension containers" {
  let uri = "urn:example:extension:2.0:User"
  let resource = projection_user().put(
    uri,
    @value.object_value([
      @value.field("costCenter", @value.string("A")),
      @value.field("region", @value.string("east")),
    ]),
  )
  let projected = project_attributes(resource, [uri + ":costCenter"], []).unwrap()
  let extension = projected.get(uri).unwrap().as_object().unwrap()
  assert_true(extension.contains("costCenter"))
  assert_false(extension.contains("region"))
}

///|
test "projection rejects conflicting and malformed selections" {
  assert_true(
    project_attributes(projection_user(), ["userName"], ["active"])
    is Err(ConflictingProjection),
  )
  assert_true(
    project_attributes(projection_user(), ["name..given"], [])
    is Err(InvalidProjectionPath(_, _)),
  )
}
