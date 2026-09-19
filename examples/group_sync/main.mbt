///|
fn main {
  let create_user = @bulk.bulk_operation(
    @bulk.Post,
    "/Users",
    bulk_id="new-employee",
    data=@value.object_value([
      @value.field("userName", @value.string("new.employee@example.com")),
    ]),
  )
  let create_group = @bulk.bulk_operation(
    @bulk.Post,
    "/Groups",
    bulk_id="engineering",
    data=@value.object_value([
      @value.field("displayName", @value.string("Engineering")),
      @value.field(
        "members",
        @value.list([
          @value.object_value([
            @value.field("value", @value.string("bulkId:new-employee")),
          ]),
        ]),
      ),
    ]),
  )
  let plan = @bulk.plan_bulk(
    @bulk.bulk_request([create_group, create_user], fail_on_errors=1),
  ).unwrap()
  if plan.source_indices() != [1, 0] {
    abort("dependency planner must place the user before the group")
  }
  let resolved_group = @bulk.resolve_bulk_operation(create_group, [
    @bulk.bulk_resolution("new-employee", "user-9001"),
  ]).unwrap()
  println(@codec.encode_value(resolved_group.data().unwrap()).unwrap())
}
