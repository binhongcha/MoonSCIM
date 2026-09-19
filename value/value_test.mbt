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
