///|
fn query_resource(
  id : String,
  name : String,
  score : Double,
  active : Bool,
) -> @value.Object {
  @value.object([
    @value.field("schemas", @value.list([@value.string("urn:user")])),
    @value.field("id", @value.string(id)),
    @value.field("userName", @value.string(name)),
    @value.field("score", @value.number(score)),
    @value.field("active", @value.boolean(active)),
  ])
}

///|
test "query filters sorts paginates and projects resources" {
  let resources = [
    query_resource("3", "carol", 9.0, true),
    query_resource("1", "alice", 7.0, true),
    query_resource("2", "bob", 8.0, false),
  ]
  let request = search_request(
    filter="active eq true",
    sort_by="score",
    descending=true,
    start_index=1,
    count=1,
    attributes=["userName"],
  ).unwrap()
  let response = execute_query(resources, request).unwrap()
  assert_eq(response.total_results(), 2)
  assert_eq(response.items_per_page(), 1)
  assert_eq(response.start_index(), 1)
  assert_eq(
    response.resources()[0].get("userName"),
    Some(@value.string("carol")),
  )
  assert_false(response.resources()[0].contains("score"))
  assert_true(response.resources()[0].contains("id"))
}

///|
test "query uses one-based indexing and clamps pages" {
  let resources = [
    query_resource("1", "alice", 7.0, true),
    query_resource("2", "bob", 8.0, true),
  ]
  let response = execute_query(
    resources,
    search_request(start_index=2, count=10).unwrap(),
  ).unwrap()
  assert_eq(response.total_results(), 2)
  assert_eq(response.items_per_page(), 1)
  assert_eq(response.resources()[0].get("id"), Some(@value.string("2")))
}

///|
test "query rejects invalid filters paths and pagination" {
  assert_true(search_request(start_index=0) is Err(InvalidPagination(_, _)))
  assert_true(search_request(count=-1) is Err(InvalidPagination(_, _)))
  assert_true(search_request(filter="userName eq") is Err(InvalidFilter(_)))
  assert_true(search_request(sort_by="name..given") is Err(InvalidSortPath(_)))
}
