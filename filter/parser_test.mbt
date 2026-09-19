///|
test "compiles comparison filters with and-before-or precedence" {
  let filter = compile_filter(
    "userName eq \"alice\" or active eq true and score ge 4.5",
  ).unwrap()
  assert_true(filter.expression() is OrExpr(_, AndExpr(_, _)))
}

///|
test "parentheses and not override default precedence" {
  let filter = compile_filter("not (active eq true or userName sw \"test-\")").unwrap()
  assert_true(filter.expression() is NotExpr(OrExpr(_, _)))
}

///|
test "compiles presence and schema-qualified attribute paths" {
  let uri = "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
  let filter = compile_filter(uri + ":employeeNumber pr").unwrap()
  assert_true(filter.expression() is Present(_))
}

///|
test "compiles complex value paths with optional trailing sub-attribute" {
  let filter = compile_filter(
    "emails[type eq \"work\" and value co \"@example.test\"].value ew \".test\"",
  ).unwrap()
  assert_true(
    filter.expression()
    is ValuePathCompare(
      _,
      AndExpr(_, _),
      Some("value"),
      EwOp,
      StringLiteral(".test")
    ),
  )
}

///|
test "reports empty trailing and malformed filters" {
  assert_true(compile_filter("") is Err(EmptyFilter))
  assert_true(compile_filter("userName eq") is Err(UnexpectedToken(_, _)))
  assert_true(
    compile_filter("userName eq \"a\" extra") is Err(TrailingToken(_)),
  )
  assert_true(
    compile_filter("name..given eq \"a\"") is Err(InvalidAttributePath(_, _)),
  )
}
