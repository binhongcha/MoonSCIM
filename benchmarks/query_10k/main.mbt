///|
fn benchmark_user(index : Int) -> @value.Object {
  @value.object([
    @value.field("id", @value.string(index.to_string())),
    @value.field("userName", @value.string("user-" + index.to_string())),
    @value.field("active", @value.boolean(index % 2 == 0)),
    @value.field(
      "department",
      @value.string(if index % 5 == 0 { "Engineering" } else { "Operations" }),
    ),
  ])
}

///|
fn main {
  let resources : Array[@value.Object] = []
  for index = 0; index < 10000; index = index + 1 {
    resources.push(benchmark_user(index))
  }
  let request = @query.search_request(
    filter="active eq true and userName sw \"user-\"",
    sort_by="userName",
    count=100,
    attributes=["id", "userName", "active"],
  ).unwrap()
  let result = @query.execute_query(resources, request).unwrap()
  if result.total_results() != 5000 || result.items_per_page() != 100 {
    abort("10k query workload returned an unexpected result")
  }
  println(
    "query_10k: matched=" +
    result.total_results().to_string() +
    " page=" +
    result.items_per_page().to_string(),
  )
}
