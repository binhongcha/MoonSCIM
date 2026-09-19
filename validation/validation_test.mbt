///|
fn test_registry() -> @schema.SchemaRegistry {
  let email = @schema.complex_attribute(
    "emails",
    [
      @schema.attribute("value", @schema.StringType, required=true),
      @schema.attribute("type", @schema.StringType, canonical_values=[
        "work", "home",
      ]),
      @schema.attribute("primary", @schema.BooleanType),
    ],
    multi_valued=true,
  )
  let user = @schema.schema(
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "User",
    [
      @schema.attribute("userName", @schema.StringType, required=true),
      @schema.attribute("active", @schema.BooleanType),
      @schema.attribute(
        "internalCode",
        @schema.StringType,
        mutability=@schema.ReadOnly,
      ),
      @schema.attribute(
        "employeeNumber",
        @schema.StringType,
        mutability=@schema.Immutable,
      ),
      @schema.attribute(
        "password",
        @schema.StringType,
        mutability=@schema.WriteOnly,
      ),
      email,
    ],
  )
  @schema.schema_registry().register(user).unwrap()
}

///|
fn user(fields : Array[@value.Field]) -> @value.Object {
  @value.object(
    [
      @value.field(
        "schemas",
        @value.list([
          @value.string("urn:ietf:params:scim:schemas:core:2.0:User"),
        ]),
      ),
      ..fields,
    ],
  )
}

///|
test "validates a well-formed resource through the public seam" {
  let resource = user([
    @value.field("userName", @value.string("alice")),
    @value.field("active", @value.boolean(true)),
    @value.field(
      "emails",
      @value.list([
        @value.object_value([
          @value.field("value", @value.string("alice@example.test")),
          @value.field("type", @value.string("work")),
          @value.field("primary", @value.boolean(true)),
        ]),
      ]),
    ),
  ])
  let report = validate_resource(
    test_registry(),
    "urn:ietf:params:scim:schemas:core:2.0:User",
    resource,
    Create,
  )
  assert_true(report.is_valid())
  assert_eq(report.diagnostics(), [])
}

///|
test "treats null and empty collections as unassigned required values" {
  let missing = validate_resource(
    test_registry(),
    "urn:ietf:params:scim:schemas:core:2.0:User",
    user([]),
    Create,
  )
  let null_name = validate_resource(
    test_registry(),
    "urn:ietf:params:scim:schemas:core:2.0:User",
    user([@value.field("userName", @value.null_value())]),
    Create,
  )
  assert_eq(missing.diagnostics()[0].code, "RESOURCE_REQUIRED")
  assert_eq(null_name.diagnostics()[0].code, "RESOURCE_REQUIRED")
}

///|
test "reports scalar and multi-valued type mismatches" {
  let resource = user([
    @value.field("userName", @value.string("alice")),
    @value.field("active", @value.string("yes")),
    @value.field("emails", @value.object_value([])),
  ])
  let report = validate_resource(
    test_registry(),
    "urn:ietf:params:scim:schemas:core:2.0:User",
    resource,
    Create,
  )
  assert_eq(report.diagnostics().length(), 2)
  assert_eq(report.diagnostics()[0].code, "RESOURCE_TYPE")
  assert_eq(report.diagnostics()[1].code, "RESOURCE_CARDINALITY")
}

///|
test "validates complex members and canonical values" {
  let resource = user([
    @value.field("userName", @value.string("alice")),
    @value.field(
      "emails",
      @value.list([
        @value.object_value([
          @value.field("type", @value.string("office")),
          @value.field("unknown", @value.string("x")),
        ]),
      ]),
    ),
  ])
  let report = validate_resource(
    test_registry(),
    "urn:ietf:params:scim:schemas:core:2.0:User",
    resource,
    Create,
  )
  assert_true(report.has_code("RESOURCE_REQUIRED"))
  assert_true(report.has_code("RESOURCE_CANONICAL"))
  assert_true(report.has_code("RESOURCE_UNKNOWN_ATTRIBUTE"))
}

///|
test "rejects unknown top-level attributes" {
  let report = validate_resource(
    test_registry(),
    "urn:ietf:params:scim:schemas:core:2.0:User",
    user([
      @value.field("userName", @value.string("alice")),
      @value.field("nicknameTypo", @value.string("ally")),
    ]),
    Create,
  )
  assert_true(report.has_code("RESOURCE_UNKNOWN_ATTRIBUTE"))
}

///|
test "operation context enforces read-only and write-only attributes" {
  let create_report = validate_resource(
    test_registry(),
    "urn:ietf:params:scim:schemas:core:2.0:User",
    user([
      @value.field("userName", @value.string("alice")),
      @value.field("internalCode", @value.string("server-owned")),
    ]),
    Create,
  )
  let response_report = validate_resource(
    test_registry(),
    "urn:ietf:params:scim:schemas:core:2.0:User",
    user([
      @value.field("userName", @value.string("alice")),
      @value.field("password", @value.string("secret")),
    ]),
    Response,
  )
  assert_true(create_report.has_code("RESOURCE_READ_ONLY"))
  assert_true(response_report.has_code("RESOURCE_WRITE_ONLY"))
}

///|
test "transition validation protects assigned immutable attributes" {
  let before = user([
    @value.field("userName", @value.string("alice")),
    @value.field("employeeNumber", @value.string("E-100")),
  ])
  let same = user([
    @value.field("userName", @value.string("alice")),
    @value.field("employeeNumber", @value.string("E-100")),
  ])
  let changed = user([
    @value.field("userName", @value.string("alice")),
    @value.field("employeeNumber", @value.string("E-200")),
  ])
  assert_true(
    validate_transition(
      test_registry(),
      "urn:ietf:params:scim:schemas:core:2.0:User",
      before,
      same,
      Replace,
    ).is_valid(),
  )
  assert_true(
    validate_transition(
      test_registry(),
      "urn:ietf:params:scim:schemas:core:2.0:User",
      before,
      changed,
      Replace,
    ).has_code("RESOURCE_IMMUTABLE"),
  )
}

///|
test "schemas declaration reports every structural failure" {
  let registry = test_registry()
  let schema_id = "urn:ietf:params:scim:schemas:core:2.0:User"
  let missing = @value.object([@value.field("userName", @value.string("alice"))])
  assert_true(
    validate_resource(registry, schema_id, missing, Create).has_code(
      "RESOURCE_SCHEMAS_REQUIRED",
    ),
  )
  let wrong_type = @value.object([
    @value.field("schemas", @value.string(schema_id)),
    @value.field("userName", @value.string("alice")),
  ])
  assert_true(
    validate_resource(registry, schema_id, wrong_type, Create).has_code(
      "RESOURCE_SCHEMAS_TYPE",
    ),
  )
  let malformed = @value.object([
    @value.field(
      "schemas",
      @value.list([
        @value.string("urn:example:unknown"),
        @value.string("URN:EXAMPLE:UNKNOWN"),
        @value.number(1.0),
      ]),
    ),
    @value.field("userName", @value.string("alice")),
  ])
  let report = validate_resource(registry, schema_id, malformed, Create)
  assert_true(report.has_code("RESOURCE_SCHEMA_UNKNOWN"))
  assert_true(report.has_code("RESOURCE_SCHEMAS_DUPLICATE"))
  assert_true(report.has_code("RESOURCE_SCHEMAS_ITEM_TYPE"))
  assert_true(report.has_code("RESOURCE_BASE_SCHEMA_MISSING"))
}

///|
test "unknown base schema produces a stable diagnostic" {
  let report = validate_resource(
    test_registry(),
    "urn:example:missing",
    @value.object([]),
    Create,
  )
  assert_eq(report.operation(), Create)
  assert_true(report.has_code("RESOURCE_SCHEMA_UNKNOWN"))
}

///|
test "registered extension containers are recursively validated" {
  let extension_id = "urn:example:params:scim:schemas:extension:2.0:User"
  let extension = @schema.schema(extension_id, "Extension", [
    @schema.attribute("department", @schema.StringType, required=true),
  ])
  let registry = test_registry().register(extension).unwrap()
  let wrong_container = user([
    @value.field("userName", @value.string("alice")),
    @value.field(extension_id, @value.string("Engineering")),
  ])
  assert_true(
    validate_resource(
      registry,
      "urn:ietf:params:scim:schemas:core:2.0:User",
      wrong_container,
      Create,
    ).has_code("RESOURCE_EXTENSION_TYPE"),
  )
  let missing_child = user([
    @value.field("userName", @value.string("alice")),
    @value.field(extension_id, @value.object_value([])),
  ])
  assert_true(
    validate_resource(
      registry,
      "urn:ietf:params:scim:schemas:core:2.0:User",
      missing_child,
      Create,
    ).has_code("RESOURCE_REQUIRED"),
  )
}

///|
test "immutable nested sub-attributes survive transition checks" {
  let profile = @schema.complex_attribute("profile", [
    @schema.attribute(
      "externalId",
      @schema.StringType,
      mutability=@schema.Immutable,
    ),
  ])
  let schema_id = "urn:example:NestedUser"
  let registry = @schema.schema_registry()
    .register(@schema.schema(schema_id, "NestedUser", [profile]))
    .unwrap()
  let before = @value.object([
    @value.field("schemas", @value.list([@value.string(schema_id)])),
    @value.field(
      "profile",
      @value.object_value([@value.field("externalId", @value.string("A"))]),
    ),
  ])
  let after = before.put(
    "profile",
    @value.object_value([@value.field("externalId", @value.string("B"))]),
  )
  assert_true(
    validate_transition(registry, schema_id, before, after, Patch).has_code(
      "RESOURCE_IMMUTABLE",
    ),
  )
}
