///|
fn user_with_emails() -> @value.Object {
  @value.object([
    @value.field(
      "emails",
      @value.list([
        @value.object_value([
          @value.field("value", @value.string("work@example.test")),
          @value.field("type", @value.string("work")),
        ]),
        @value.object_value([
          @value.field("value", @value.string("home@example.test")),
          @value.field("type", @value.string("home")),
        ]),
      ]),
    ),
  ])
}

///|
test "removes selected values using a SCIM value filter" {
  let updated = apply_patch(user_with_emails(), [
    remove("emails[type eq \"home\"]"),
  ]).unwrap()
  let emails = updated.get("emails").unwrap().as_list().unwrap()
  assert_eq(emails.length(), 1)
  assert_eq(
    emails[0].as_object().unwrap().get("type"),
    Some(@value.string("work")),
  )
}

///|
test "replaces a sub-attribute on every selected complex value" {
  let updated = apply_patch(user_with_emails(), [
    replace("emails[type eq \"work\"].value", @value.string("new@example.test")),
  ]).unwrap()
  let emails = updated.get("emails").unwrap().as_list().unwrap()
  assert_eq(
    emails[0].as_object().unwrap().get("value"),
    Some(@value.string("new@example.test")),
  )
  assert_eq(
    emails[1].as_object().unwrap().get("value"),
    Some(@value.string("home@example.test")),
  )
}

///|
test "filtered patch fails when no value matches" {
  let result = apply_patch(user_with_emails(), [
    remove("emails[type eq \"other\"]"),
  ])
  assert_true(result is Err(TargetMissing(_, _)))
}

///|
test "filtered patch reports malformed bracket and suffix syntax" {
  assert_true(
    apply_patch(user_with_emails(), [remove("emails[type eq \"work\"")])
    is Err(InvalidFilteredPath(_, _)),
  )
  assert_true(
    apply_patch(user_with_emails(), [remove("emails[type eq \"work\"]value")])
    is Err(InvalidFilteredPath(_, _)),
  )
}
