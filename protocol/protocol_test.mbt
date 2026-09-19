///|
fn user(id : String) -> @value.Object {
  @value.object([
    @value.field("id", @value.string(id)),
    @value.field("userName", @value.string("user-" + id)),
  ])
}

///|
test "query result becomes a standards-shaped ListResponse" {
  let request = @query.search_request(start_index=2, count=1).unwrap()
  let result = @query.execute_query([user("1"), user("2")], request).unwrap()
  let message = list_response(result)
  assert_eq(message.get("totalResults"), Some(@value.number(2.0)))
  assert_eq(message.get("startIndex"), Some(@value.number(2.0)))
  assert_eq(message.get("itemsPerPage"), Some(@value.number(1.0)))
  assert_eq(
    message.get("Resources"),
    Some(@value.list([@value.object_value(user("2").entries())])),
  )
}

///|
test "SCIM error response uses string status and optional scimType" {
  let error = error_response(400, "invalid filter", scim_type="invalidFilter")
  assert_eq(error.get("status"), Some(@value.string("400")))
  assert_eq(error.get("scimType"), Some(@value.string("invalidFilter")))
}

///|
test "service provider discovery advertises configured capabilities" {
  let oauth = authentication_scheme(
    "oauthbearertoken",
    "OAuth Bearer Token",
    spec_uri="https://www.rfc-editor.org/info/rfc6750",
  )
  let resource = service_provider_config_resource(
    service_provider_config(bulk_max_operations=500, filter_max_results=100, authentication_schemes=[
      oauth,
    ]),
  )
  assert_eq(
    resource.get("patch"),
    Some(@value.object_value([@value.field("supported", @value.boolean(true))])),
  )
  assert_eq(
    resource.get("authenticationSchemes").unwrap().as_list().unwrap().length(),
    1,
  )
}

///|
test "schema discovery includes nested attribute metadata" {
  let sample = @schema.schema(
    "urn:example:User",
    "ExampleUser",
    [
      @schema.complex_attribute(
        "name",
        [@schema.attribute("formatted", @schema.StringType)],
        description="A display name",
      ),
    ],
    description="Example schema",
  )
  let resource = schema_resource(sample)
  assert_eq(resource.get("id"), Some(@value.string("urn:example:User")))
  let attributes = resource.get("attributes").unwrap().as_list().unwrap()
  let name = attributes[0].as_object().unwrap()
  assert_eq(name.get("type"), Some(@value.string("complex")))
  assert_eq(name.get("subAttributes").unwrap().as_list().unwrap().length(), 1)
}

///|
test "resource type discovery records optional schema extensions" {
  let resource = resource_type_resource("User", "/Users", "urn:example:User", extensions=[
    schema_extension("urn:example:EnterpriseUser"),
  ])
  assert_eq(resource.get("endpoint"), Some(@value.string("/Users")))
  assert_eq(
    resource.get("schemaExtensions").unwrap().as_list().unwrap().length(),
    1,
  )
}
