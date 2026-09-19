///|
test "object lookup is case insensitive and preserves declared spelling" {
  let resource = object([
    field("userName", string("alice")),
    field("active", boolean(true)),
  ])
  assert_eq(resource.get("USERNAME"), Some(string("alice")))
  assert_eq(resource.get("Active"), Some(boolean(true)))
  assert_eq(resource.names(), ["userName", "active"])
}

///|
test "object replacement keeps original position and spelling" {
  let resource = object([
    field("userName", string("alice")),
    field("active", boolean(true)),
  ])
  let updated = resource.put("USERNAME", string("bob"))
  assert_eq(updated.get("userName"), Some(string("bob")))
  assert_eq(updated.names(), ["userName", "active"])
  assert_eq(resource.get("userName"), Some(string("alice")))
}

///|
test "object removal is case insensitive and immutable" {
  let resource = object([
    field("userName", string("alice")),
    field("active", boolean(true)),
  ])
  let updated = resource.remove("ACTIVE")
  assert_eq(updated.get("active"), None)
  assert_eq(resource.get("active"), Some(boolean(true)))
}

///|
test "nested values retain scalar and collection kinds" {
  let resource = object([
    field("score", number(3.5)),
    field("tags", list([string("admin"), string("owner")])),
    field("missing", null_value()),
  ])
  assert_eq(resource.get("score"), Some(number(3.5)))
  assert_eq(
    resource.get("tags"),
    Some(list([string("admin"), string("owner")])),
  )
  assert_eq(resource.get("missing"), Some(null_value()))
}

///|
test "field snapshots expose names and values without exposing object storage" {
  let resource = object([field("userName", string("alice"))])
  let entries = resource.entries()
  assert_eq(entries[0].name(), "userName")
  assert_eq(entries[0].value(), string("alice"))
  entries.push(field("active", boolean(true)))
  assert_eq(resource.length(), 1)
}

///|
test "value accessors reject mismatched kinds" {
  assert_eq(string("alice").as_string(), Some("alice"))
  assert_eq(string("alice").as_boolean(), None)
  assert_eq(boolean(false).as_boolean(), Some(false))
  assert_eq(list([]).as_list(), Some([]))
  assert_true(null_value().is_null())
}
