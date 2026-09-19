///|
pub fn user_schema_id() -> String {
  "urn:ietf:params:scim:schemas:core:2.0:User"
}

///|
pub fn group_schema_id() -> String {
  "urn:ietf:params:scim:schemas:core:2.0:Group"
}

///|
pub fn enterprise_user_schema_id() -> String {
  "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
}

///|
pub fn user_schema() -> @schema.Schema {
  @schema.schema(
    user_schema_id(),
    "User",
    [
      @schema.attribute(
        "userName",
        @schema.StringType,
        required=true,
        uniqueness=@schema.Server,
      ),
      person_name(),
      @schema.attribute("displayName", @schema.StringType),
      @schema.attribute("nickName", @schema.StringType),
      @schema.attribute("profileUrl", @schema.ReferenceType, reference_types=[
        "external",
      ]),
      @schema.attribute("title", @schema.StringType),
      @schema.attribute("userType", @schema.StringType),
      @schema.attribute("preferredLanguage", @schema.StringType),
      @schema.attribute("locale", @schema.StringType),
      @schema.attribute("timezone", @schema.StringType),
      @schema.attribute("active", @schema.BooleanType),
      @schema.attribute(
        "password",
        @schema.StringType,
        mutability=@schema.WriteOnly,
        returned=@schema.Never,
      ),
      typed_values("emails", "Email address values"),
      typed_values("phoneNumbers", "Telephone number values"),
      typed_values("ims", "Instant messaging addresses"),
      photo_values(),
      address_values(),
      group_memberships(),
      @schema.attribute("entitlements", @schema.StringType, multi_valued=true),
      @schema.attribute("roles", @schema.StringType, multi_valued=true),
      @schema.attribute(
        "x509Certificates",
        @schema.BinaryType,
        multi_valued=true,
      ),
    ],
    description="RFC 7643 core User resource schema",
  )
}

///|
pub fn group_schema() -> @schema.Schema {
  @schema.schema(
    group_schema_id(),
    "Group",
    [
      @schema.attribute("displayName", @schema.StringType, required=true),
      @schema.complex_attribute(
        "members",
        [
          @schema.attribute(
            "value",
            @schema.StringType,
            mutability=@schema.Immutable,
          ),
          @schema.attribute(
            "$ref",
            @schema.ReferenceType,
            reference_types=["User", "Group"],
            mutability=@schema.Immutable,
          ),
          @schema.attribute(
            "type",
            @schema.StringType,
            canonical_values=["User", "Group"],
            mutability=@schema.Immutable,
          ),
        ],
        multi_valued=true,
      ),
    ],
    description="RFC 7643 core Group resource schema",
  )
}

///|
pub fn enterprise_user_schema() -> @schema.Schema {
  @schema.schema(
    enterprise_user_schema_id(),
    "EnterpriseUser",
    [
      @schema.attribute("employeeNumber", @schema.StringType),
      @schema.attribute("costCenter", @schema.StringType),
      @schema.attribute("organization", @schema.StringType),
      @schema.attribute("division", @schema.StringType),
      @schema.attribute("department", @schema.StringType),
      @schema.complex_attribute("manager", [
        @schema.attribute(
          "value",
          @schema.StringType,
          mutability=@schema.ReadWrite,
        ),
        @schema.attribute("$ref", @schema.ReferenceType, reference_types=[
          "User",
        ]),
        @schema.attribute(
          "displayName",
          @schema.StringType,
          mutability=@schema.ReadOnly,
        ),
      ]),
    ],
    description="RFC 7643 enterprise User extension",
  )
}

///|
pub fn standard_registry() -> @schema.SchemaRegistry {
  @schema.schema_registry()
  .register(user_schema())
  .unwrap()
  .register(group_schema())
  .unwrap()
  .register(enterprise_user_schema())
  .unwrap()
}

///|
fn person_name() -> @schema.AttributeDefinition {
  @schema.complex_attribute("name", [
    @schema.attribute("formatted", @schema.StringType),
    @schema.attribute("familyName", @schema.StringType),
    @schema.attribute("givenName", @schema.StringType),
    @schema.attribute("middleName", @schema.StringType),
    @schema.attribute("honorificPrefix", @schema.StringType),
    @schema.attribute("honorificSuffix", @schema.StringType),
  ])
}

///|
fn typed_values(
  name : String,
  description : String,
) -> @schema.AttributeDefinition {
  @schema.complex_attribute(
    name,
    [
      @schema.attribute("value", @schema.StringType),
      @schema.attribute("display", @schema.StringType),
      @schema.attribute("type", @schema.StringType),
      @schema.attribute("primary", @schema.BooleanType),
    ],
    multi_valued=true,
    description~,
  )
}

///|
fn photo_values() -> @schema.AttributeDefinition {
  @schema.complex_attribute(
    "photos",
    [
      @schema.attribute("value", @schema.ReferenceType, reference_types=[
        "external",
      ]),
      @schema.attribute("display", @schema.StringType),
      @schema.attribute("type", @schema.StringType, canonical_values=[
        "photo", "thumbnail",
      ]),
      @schema.attribute("primary", @schema.BooleanType),
    ],
    multi_valued=true,
  )
}

///|
fn address_values() -> @schema.AttributeDefinition {
  @schema.complex_attribute(
    "addresses",
    [
      @schema.attribute("formatted", @schema.StringType),
      @schema.attribute("streetAddress", @schema.StringType),
      @schema.attribute("locality", @schema.StringType),
      @schema.attribute("region", @schema.StringType),
      @schema.attribute("postalCode", @schema.StringType),
      @schema.attribute("country", @schema.StringType),
      @schema.attribute("type", @schema.StringType),
      @schema.attribute("primary", @schema.BooleanType),
    ],
    multi_valued=true,
  )
}

///|
fn group_memberships() -> @schema.AttributeDefinition {
  @schema.complex_attribute(
    "groups",
    [
      @schema.attribute("value", @schema.StringType),
      @schema.attribute("$ref", @schema.ReferenceType, reference_types=["Group"]),
      @schema.attribute(
        "display",
        @schema.StringType,
        mutability=@schema.ReadOnly,
      ),
      @schema.attribute(
        "type",
        @schema.StringType,
        canonical_values=["direct", "indirect"],
        mutability=@schema.ReadOnly,
      ),
    ],
    multi_valued=true,
    mutability=@schema.ReadOnly,
  )
}
