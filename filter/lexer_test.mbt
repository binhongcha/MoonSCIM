///|
test "tokenizes comparison and logical operators case insensitively" {
  let tokens = lex_filter(
    "userName Eq \"bjensen\" and (active EQ true or score ge 4.5)",
  ).unwrap()
  assert_eq(tokens[0].kind(), Identifier("userName"))
  assert_eq(tokens[1].kind(), Eq)
  assert_eq(tokens[2].kind(), StringValue("bjensen"))
  assert_eq(tokens[3].kind(), And)
  assert_eq(tokens[4].kind(), LeftParen)
  assert_eq(tokens[6].kind(), Eq)
  assert_eq(tokens[7].kind(), BooleanValue(true))
  assert_eq(tokens[8].kind(), Or)
  assert_eq(tokens[10].kind(), Ge)
  assert_eq(tokens[11].kind(), NumberValue("4.5"))
  assert_eq(tokens[12].kind(), RightParen)
  assert_eq(tokens[13].kind(), End)
}

///|
test "tokenizes value paths and presence operators" {
  let tokens = lex_filter(
    "emails[type eq \"work\" and value co \"@\"].value pr",
  ).unwrap()
  assert_eq(tokens[0].kind(), Identifier("emails"))
  assert_eq(tokens[1].kind(), LeftBracket)
  assert_eq(tokens[7].kind(), Co)
  assert_eq(tokens[9].kind(), RightBracket)
  assert_eq(tokens[10].kind(), Identifier(".value"))
  assert_eq(tokens[11].kind(), Pr)
}

///|
test "decodes JSON string escapes and tracks source offsets" {
  let tokens = lex_filter("displayName eq \"A\\nB\\\"C\\\\D\"").unwrap()
  assert_eq(tokens[2].kind(), StringValue("A\nB\"C\\D"))
  assert_eq(tokens[0].offset(), 0)
  assert_eq(tokens[1].offset(), 12)
}

///|
test "recognizes every RFC comparison operator" {
  let tokens = lex_filter(
    "a ne 1 and b co \"x\" and c sw \"y\" and d ew \"z\" and e gt 1 and f lt 2 and g le 3",
  ).unwrap()
  let kinds = tokens.map(token => token.kind())
  assert_true(kinds.contains(Ne))
  assert_true(kinds.contains(Co))
  assert_true(kinds.contains(Sw))
  assert_true(kinds.contains(Ew))
  assert_true(kinds.contains(Gt))
  assert_true(kinds.contains(Lt))
  assert_true(kinds.contains(Le))
}

///|
test "rejects unterminated and invalid string escapes" {
  assert_true(lex_filter("userName eq \"alice") is Err(UnterminatedString(_)))
  assert_true(lex_filter("userName eq \"a\\q\"") is Err(InvalidEscape(_, _)))
  assert_true(lex_filter("active eq @") is Err(InvalidToken(_, _)))
}
