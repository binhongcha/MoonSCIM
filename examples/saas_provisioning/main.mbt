///|
fn main {
  let user = @value.object([
    @value.field(
      "schemas",
      @value.list([@value.string(@standard.user_schema_id())]),
    ),
    @value.field("id", @value.string("2819c223-7f76-453a-919d-413861904646")),
    @value.field("userName", @value.string("alice@example.com")),
    @value.field("active", @value.boolean(true)),
    @value.field(
      "emails",
      @value.list([
        @value.object_value([
          @value.field("value", @value.string("alice@example.com")),
          @value.field("type", @value.string("work")),
          @value.field("primary", @value.boolean(true)),
        ]),
      ]),
    ),
  ])
  let validation = @validation.validate_resource(
    @standard.standard_registry(),
    @standard.user_schema_id(),
    user,
    @validation.Create,
  )
  if !validation.is_valid() {
    abort("the provisioning example must remain schema-valid")
  }
  let provisioned = @patch.apply_patch(user, [
    @patch.add("roles", @value.list([@value.string("billing-admin")])),
    @patch.add("displayName", @value.string("Alice Example")),
  ]).unwrap()
  let response_validation = @validation.validate_resource(
    @standard.standard_registry(),
    @standard.user_schema_id(),
    provisioned,
    @validation.Response,
  )
  if !response_validation.is_valid() {
    abort("the provisioned response must remain schema-valid")
  }
  let request = @query.search_request(
    filter="active eq true and roles co \"admin\"",
    sort_by="userName",
    count=25,
  ).unwrap()
  let page = @query.execute_query([provisioned], request).unwrap()
  println(@codec.encode_object(@protocol.list_response(page)).unwrap())
}
