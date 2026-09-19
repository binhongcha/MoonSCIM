///|
test "standard registry includes user group and enterprise schemas" {
  let registry = standard_registry()
  assert_eq(registry.length(), 3)
  assert_true(registry.find(user_schema_id()) is Some(_))
  assert_true(registry.find(group_schema_id()) is Some(_))
  assert_true(registry.find(enterprise_user_schema_id()) is Some(_))
}

///|
test "all built-in schemas are internally valid" {
  assert_eq(@schema.validate_schema(user_schema()), [])
  assert_eq(@schema.validate_schema(group_schema()), [])
  assert_eq(@schema.validate_schema(enterprise_user_schema()), [])
}

///|
test "user schema exposes required and security-sensitive characteristics" {
  let user = user_schema()
  let username = user.attribute("userName").unwrap()
  let password = user.attribute("password").unwrap()
  let groups = user.attribute("groups").unwrap()
  assert_true(username.required())
  assert_eq(username.uniqueness(), @schema.Server)
  assert_eq(password.mutability(), @schema.WriteOnly)
  assert_eq(password.returned(), @schema.Never)
  assert_eq(groups.mutability(), @schema.ReadOnly)
}

///|
test "group and enterprise schemas expose interoperable reference shapes" {
  let members = group_schema().attribute("members").unwrap()
  assert_true(members.multi_valued())
  assert_true(members.sub_attributes().length() >= 3)
  let manager = enterprise_user_schema().attribute("manager").unwrap()
  assert_eq(manager.attribute_type(), @schema.ComplexType)
  assert_true(manager.sub_attributes().length() >= 2)
}
