///|
fn example_resource() -> @value.Object {
  @value.object([
    @value.field(
      "schemas",
      @value.list([@value.string("urn:ietf:params:scim:schemas:core:2.0:User")]),
    ),
    @value.field("userName", @value.string("alice\u{1f680}")),
    @value.field("active", @value.boolean(true)),
    @value.field("score", @value.number(3.5)),
    @value.field(
      "name",
      @value.object_value([
        @value.field("givenName", @value.string("Alice")),
        @value.field("familyName", @value.string("Example")),
      ]),
    ),
    @value.field("manager", @value.null_value()),
  ])
}

///|
test "resource JSON round trip preserves SCIM values and field order" {
  let resource = example_resource()
  let encoded = encode_object(resource).unwrap()
  let decoded = decode_object(encoded).unwrap()
  assert_eq(decoded, resource)
  assert_true(encoded.has_prefix("{\"schemas\":"))
  assert_true(encoded.contains("alice"))
}

///|
test "decoder rejects a non-object resource root" {
  assert_eq(decode_object("[1,2,3]"), Err(RootNotObject))
}

///|
test "decoder rejects case-insensitive duplicate SCIM attributes" {
  assert_eq(
    decode_object("{\"userName\":\"alice\",\"USERNAME\":\"mallory\"}"),
    Err(DuplicateAttribute("USERNAME")),
  )
}

///|
test "decoder applies input, depth, and node budgets" {
  assert_eq(
    decode_value("{\"abc\":1}", limits=codec_limits(max_chars=4)),
    Err(InputTooLarge(9, 4)),
  )
  assert_eq(
    decode_value("[[[0]]]", limits=codec_limits(max_depth=2)),
    Err(NestingTooDeep(3)),
  )
  assert_eq(
    decode_value("[1,2,3]", limits=codec_limits(max_nodes=3)),
    Err(TooManyNodes(4)),
  )
}

///|
test "decoder reports malformed JSON without panicking" {
  match decode_value("{\"userName\":}") {
    Err(InvalidJson(_)) => ()
    _ => abort("expected InvalidJson")
  }
}

///|
test "encoder rejects numbers that JSON cannot represent" {
  assert_eq(encode_value(@value.number(0.0 / 0.0)), Err(NonFiniteNumber))
}

///|
test "arbitrary JSON values use the same bounded conversion" {
  assert_eq(
    decode_value("[true,false,null,1.25,\"x\"]").unwrap(),
    @value.list([
      @value.boolean(true),
      @value.boolean(false),
      @value.null_value(),
      @value.number(1.25),
      @value.string("x"),
    ]),
  )
}
