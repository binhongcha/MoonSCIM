///|
test "bulk request captures methods identifiers paths and values" {
  let request = bulk_request(
    [
      bulk_operation(
        Post,
        "/Users",
        bulk_id="user-1",
        data=@value.object_value([
          @value.field("userName", @value.string("alice")),
        ]),
      ),
      bulk_operation(Delete, "/Users/42"),
    ],
    fail_on_errors=1,
  )
  assert_eq(request.operations().length(), 2)
  assert_eq(request.fail_on_errors(), Some(1))
  assert_eq(request.operations()[0].bulk_method(), Post)
  assert_eq(request.operations()[0].bulk_id(), Some("user-1"))
}

///|
test "bulk request validates method data and path requirements" {
  let request = bulk_request(
    [
      bulk_operation(Post, "", bulk_id="new", data=@value.object_value([])),
      bulk_operation(Post, "/Users", bulk_id="missing-data"),
      bulk_operation(Delete, "/Users/1", data=@value.object_value([])),
    ],
    fail_on_errors=-1,
  )
  let issues = validate_bulk_request(request)
  assert_true(issues.has_code("BULK_FAIL_ON_ERRORS"))
  assert_true(issues.has_code("BULK_PATH_REQUIRED"))
  assert_true(issues.has_code("BULK_DATA_REQUIRED"))
  assert_true(issues.has_code("BULK_DELETE_DATA"))
}

///|
test "bulk request rejects duplicate and empty bulk identifiers" {
  let request = bulk_request([
    bulk_operation(Post, "/Users", bulk_id="", data=@value.object_value([])),
    bulk_operation(Post, "/Users", bulk_id="same", data=@value.object_value([])),
    bulk_operation(
      Post,
      "/Groups",
      bulk_id="SAME",
      data=@value.object_value([]),
    ),
  ])
  let issues = validate_bulk_request(request)
  assert_true(issues.has_code("BULK_ID_EMPTY"))
  assert_true(issues.has_code("BULK_ID_DUPLICATE"))
}

///|
test "bulk limits reject oversized operation arrays" {
  let request = bulk_request([
    bulk_operation(Delete, "/Users/1"),
    bulk_operation(Delete, "/Users/2"),
  ])
  let issues = validate_bulk_request(request, max_operations=1)
  assert_true(issues.has_code("BULK_OPERATION_LIMIT"))
}
