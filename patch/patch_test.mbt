///|
fn patch_user() -> @value.Object {
  @value.object([
    @value.field("userName", @value.string("alice")),
    @value.field("active", @value.boolean(true)),
    @value.field(
      "name",
      @value.object_value([
        @value.field("givenName", @value.string("Alice")),
        @value.field("familyName", @value.string("Old")),
      ]),
    ),
    @value.field("roles", @value.list([@value.string("reader")])),
  ])
}

///|
test "applies add replace and remove atomically without mutating input" {
  let original = patch_user()
  let updated = apply_patch(original, [
    add("displayName", @value.string("Alice Example")),
    replace("name.familyName", @value.string("New")),
    remove("active"),
  ]).unwrap()
  assert_eq(updated.get("displayName"), Some(@value.string("Alice Example")))
  assert_eq(updated.get("active"), None)
  assert_eq(
    updated.get("name").unwrap().as_object().unwrap().get("familyName"),
    Some(@value.string("New")),
  )
  assert_eq(original.get("active"), Some(@value.boolean(true)))
}

///|
test "add appends to an existing multi-valued attribute" {
  let updated = apply_patch(patch_user(), [
    add("roles", @value.string("writer")),
    add("roles", @value.list([@value.string("auditor")])),
  ]).unwrap()
  assert_eq(updated.get("roles").unwrap().as_list().unwrap(), [
    @value.string("reader"),
    @value.string("writer"),
    @value.string("auditor"),
  ])
}

///|
test "updates schema extension containers" {
  let uri = "urn:example:schemas:extension:2.0:User"
  let resource = patch_user().put(
    uri,
    @value.object_value([@value.field("costCenter", @value.string("A"))]),
  )
  let updated = apply_patch(resource, [
    replace(uri + ":costCenter", @value.string("B")),
  ]).unwrap()
  assert_eq(
    updated.get(uri).unwrap().as_object().unwrap().get("costCenter"),
    Some(@value.string("B")),
  )
}

///|
test "failed operation returns an error and leaves the source observable" {
  let original = patch_user()
  let result = apply_patch(original, [
    replace("displayName", @value.string("temporary")),
    remove("missing"),
  ])
  assert_true(result is Err(TargetMissing(_, _)))
  assert_eq(original.get("displayName"), None)
}

///|
test "rejects malformed paths and values missing for write operations" {
  assert_true(
    apply_patch(patch_user(), [raw_operation(Add, "", None)])
    is Err(MissingValue(_)),
  )
  assert_true(
    apply_patch(patch_user(), [remove("name..given")])
    is Err(InvalidPatchPath(_, _)),
  )
}
