///|
test "planner orders forward bulkId dependencies before consumers" {
  let group = bulk_operation(
    Post,
    "/Groups",
    bulk_id="group-1",
    data=@value.object_value([
      @value.field(
        "members",
        @value.list([
          @value.object_value([
            @value.field("value", @value.string("bulkId:user-1")),
          ]),
        ]),
      ),
    ]),
  )
  let user = bulk_operation(
    Post,
    "/Users",
    bulk_id="user-1",
    data=@value.object_value([]),
  )
  let plan = plan_bulk(bulk_request([group, user])).unwrap()
  assert_eq(plan.ordered_operations()[0].bulk_id(), Some("user-1"))
  assert_eq(plan.ordered_operations()[1].bulk_id(), Some("group-1"))
  assert_eq(plan.source_indices(), [1, 0])
}

///|
test "planner preserves source order for independent operations" {
  let plan = plan_bulk(
    bulk_request([
      bulk_operation(Delete, "/Users/1"),
      bulk_operation(Delete, "/Users/2"),
      bulk_operation(Delete, "/Users/3"),
    ]),
  ).unwrap()
  assert_eq(plan.source_indices(), [0, 1, 2])
}

///|
test "planner rejects unknown references and dependency cycles" {
  let unknown = bulk_request([bulk_operation(Delete, "/Users/bulkId:missing")])
  assert_true(plan_bulk(unknown) is Err(UnknownBulkId(0, "missing")))
  let cycle = bulk_request([
    bulk_operation(
      Patch,
      "/Users/bulkId:b",
      bulk_id="a",
      data=@value.object_value([]),
    ),
    bulk_operation(
      Patch,
      "/Users/bulkId:a",
      bulk_id="b",
      data=@value.object_value([]),
    ),
  ])
  assert_true(plan_bulk(cycle) is Err(DependencyCycle(_)))
}

///|
test "resolved operation substitutes references in path and nested data" {
  let operation = bulk_operation(
    Patch,
    "/Groups/bulkId:group-1",
    data=@value.object_value([
      @value.field(
        "member",
        @value.object_value([
          @value.field("value", @value.string("bulkId:user-1")),
        ]),
      ),
    ]),
  )
  let resolved = resolve_bulk_operation(operation, [
    bulk_resolution("group-1", "g-42"),
    bulk_resolution("user-1", "u-7"),
  ]).unwrap()
  assert_eq(resolved.path(), "/Groups/g-42")
  assert_eq(
    resolved
    .data()
    .unwrap()
    .as_object()
    .unwrap()
    .get("member")
    .unwrap()
    .as_object()
    .unwrap()
    .get("value"),
    Some(@value.string("u-7")),
  )
}

///|
test "resolution fails rather than leaking unresolved placeholders" {
  let operation = bulk_operation(Delete, "/Users/bulkId:missing")
  assert_true(
    resolve_bulk_operation(operation, []) is Err(MissingResolution("missing")),
  )
}

///|
test "planner rejects an invalid request before dependency analysis" {
  let invalid = bulk_request([bulk_operation(Post, "/Users")])
  match plan_bulk(invalid) {
    Err(InvalidBulkRequest(issues)) => {
      assert_true(issues.has_code("BULK_DATA_REQUIRED"))
      let snapshot = issues.items()
      assert_eq(snapshot.length(), 1)
    }
    _ => abort("expected InvalidBulkRequest")
  }
}

///|
test "resolution handles no-data operations and nested lists" {
  let deleted = resolve_bulk_operation(
    bulk_operation(Delete, "/Users/bulkId:user"),
    [bulk_resolution("user", "u-1")],
  ).unwrap()
  assert_eq(deleted.path(), "/Users/u-1")
  assert_eq(deleted.data(), None)
  let nested = bulk_operation(
    Patch,
    "/Groups/1",
    data=@value.list([
      @value.object_value([@value.field("value", @value.string("bulkId:user"))]),
      @value.string("literal"),
    ]),
  )
  let resolved = resolve_bulk_operation(nested, [bulk_resolution("user", "u-1")])
    .unwrap()
    .data()
    .unwrap()
    .as_list()
    .unwrap()
  assert_eq(
    resolved[0].as_object().unwrap().get("value"),
    Some(@value.string("u-1")),
  )
  assert_eq(resolved[1], @value.string("literal"))
}

///|
test "missing resolution inside nested data is reported" {
  let operation = bulk_operation(
    Patch,
    "/Groups/1",
    data=@value.list([@value.string("bulkId:missing")]),
  )
  assert_true(
    resolve_bulk_operation(operation, []) is Err(MissingResolution("missing")),
  )
}
