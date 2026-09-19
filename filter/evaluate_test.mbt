///|
fn filter_user() -> @value.Object {
  @value.object([
    @value.field("userName", @value.string("Alice")),
    @value.field("active", @value.boolean(true)),
    @value.field("score", @value.number(7.5)),
    @value.field(
      "emails",
      @value.list([
        @value.object_value([
          @value.field("value", @value.string("alice@example.test")),
          @value.field("type", @value.string("work")),
        ]),
        @value.object_value([
          @value.field("value", @value.string("alice@home.test")),
          @value.field("type", @value.string("home")),
        ]),
      ]),
    ),
  ])
}

///|
test "evaluates presence equality and missing attributes" {
  let resource = filter_user()
  assert_true(compile_filter("userName pr").unwrap().matches(resource))
  assert_true(
    compile_filter("username eq \"alice\"").unwrap().matches(resource),
  )
  assert_false(compile_filter("missing ne \"x\"").unwrap().matches(resource))
}

///|
test "evaluates logical and ordered numeric comparisons" {
  let resource = filter_user()
  assert_true(
    compile_filter("active eq true and score gt 7").unwrap().matches(resource),
  )
  assert_false(compile_filter("not (score ge 7.5)").unwrap().matches(resource))
}

///|
test "evaluates string contains starts-with and ends-with" {
  let resource = filter_user()
  assert_true(compile_filter("userName co \"lic\"").unwrap().matches(resource))
  assert_true(compile_filter("userName sw \"al\"").unwrap().matches(resource))
  assert_true(compile_filter("userName ew \"ICE\"").unwrap().matches(resource))
}

///|
test "evaluates multi-valued complex value paths" {
  let resource = filter_user()
  assert_true(
    compile_filter("emails[type eq \"work\"].value co \"@example\"")
    .unwrap()
    .matches(resource),
  )
  assert_false(
    compile_filter("emails[type eq \"home\"].value co \"@example\"")
    .unwrap()
    .matches(resource),
  )
  assert_true(
    compile_filter("emails[type eq \"work\"] pr").unwrap().matches(resource),
  )
}
