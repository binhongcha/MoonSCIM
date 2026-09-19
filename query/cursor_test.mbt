///|
test "cursor pagination advances without exposing an index parameter" {
  let resources = [
    query_resource("1", "alice", 7.0, true),
    query_resource("2", "bob", 8.0, true),
    query_resource("3", "carol", 9.0, true),
  ]
  let request = search_request(sort_by="userName", count=2).unwrap()
  let first = execute_cursor_query(resources, request, None).unwrap()
  assert_eq(first.resources().length(), 2)
  assert_true(first.next_cursor() is Some(_))
  let second = execute_cursor_query(resources, request, first.next_cursor()).unwrap()
  assert_eq(second.resources().length(), 1)
  assert_eq(second.resources()[0].get("id"), Some(@value.string("3")))
  assert_eq(second.next_cursor(), None)
}

///|
test "cursor is bound to the normalized query" {
  let resources = [
    query_resource("1", "alice", 7.0, true),
    query_resource("2", "bob", 8.0, false),
    query_resource("3", "carol", 9.0, true),
  ]
  let active = search_request(filter="active eq true", count=1).unwrap()
  let cursor = execute_cursor_query(resources, active, None)
    .unwrap()
    .next_cursor()
  let different = search_request(filter="active eq false", count=1).unwrap()
  assert_true(
    execute_cursor_query(resources, different, cursor)
    is Err(CursorQueryMismatch),
  )
}

///|
test "cursor rejects malformed versions offsets and checksums" {
  let request = search_request(count=1).unwrap()
  assert_true(
    execute_cursor_query([], request, Some("bad")) is Err(InvalidCursor(_)),
  )
  assert_true(
    execute_cursor_query([], request, Some("mcs2:0:1")) is Err(InvalidCursor(_)),
  )
  assert_true(
    execute_cursor_query([], request, Some("mcs1:-1:1"))
    is Err(InvalidCursor(_)),
  )
  assert_true(
    execute_cursor_query([], request, Some("mcs1:0:999"))
    is Err(CursorQueryMismatch),
  )
}
