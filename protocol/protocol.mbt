///|
pub fn error_schema_id() -> String {
  "urn:ietf:params:scim:api:messages:2.0:Error"
}

///|
pub fn list_response_schema_id() -> String {
  "urn:ietf:params:scim:api:messages:2.0:ListResponse"
}

///|
pub fn service_provider_config_schema_id() -> String {
  "urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"
}

///|
pub fn resource_type_schema_id() -> String {
  "urn:ietf:params:scim:schemas:core:2.0:ResourceType"
}

///|
pub fn schema_resource_schema_id() -> String {
  "urn:ietf:params:scim:schemas:core:2.0:Schema"
}

///|
/// Build an RFC 7644 error response without coupling callers to an HTTP stack.
pub fn error_response(
  status : Int,
  detail : String,
  scim_type? : String,
) -> @value.Object {
  let fields = base_fields(error_schema_id())
  fields.push(@value.field("status", @value.string(status.to_string())))
  if !detail.is_empty() {
    fields.push(@value.field("detail", @value.string(detail)))
  }
  match scim_type {
    Some(value) if !value.is_empty() =>
      fields.push(@value.field("scimType", @value.string(value)))
    _ => ()
  }
  @value.object(fields)
}

///|
/// Convert an index-paginated query result to the RFC ListResponse envelope.
pub fn list_response(response : @query.ListResponse) -> @value.Object {
  @value.object([
    @value.field(
      "schemas",
      @value.list([@value.string(list_response_schema_id())]),
    ),
    @value.field(
      "totalResults",
      @value.number(response.total_results().to_double()),
    ),
    @value.field(
      "startIndex",
      @value.number(response.start_index().to_double()),
    ),
    @value.field(
      "itemsPerPage",
      @value.number(response.items_per_page().to_double()),
    ),
    @value.field(
      "Resources",
      @value.list(
        response
        .resources()
        .map(resource => @value.object_value(resource.entries())),
      ),
    ),
  ])
}

///|
/// Encode an RFC 9865 cursor page. Cursor fields are omitted when absent.
pub fn cursor_response(response : @query.CursorResponse) -> @value.Object {
  let fields : Array[@value.Field] = [
    @value.field(
      "schemas",
      @value.list([@value.string(list_response_schema_id())]),
    ),
    @value.field(
      "totalResults",
      @value.number(response.total_results().to_double()),
    ),
    @value.field(
      "itemsPerPage",
      @value.number(response.items_per_page().to_double()),
    ),
    @value.field(
      "Resources",
      @value.list(
        response
        .resources()
        .map(resource => @value.object_value(resource.entries())),
      ),
    ),
  ]
  match response.next_cursor() {
    Some(cursor) =>
      fields.push(@value.field("nextCursor", @value.string(cursor)))
    None => ()
  }
  match response.previous_cursor() {
    Some(cursor) =>
      fields.push(@value.field("previousCursor", @value.string(cursor)))
    None => ()
  }
  @value.object(fields)
}

///|
pub(all) struct AuthenticationScheme {
  scheme_type : String
  name : String
  description : String
  spec_uri : String
  documentation_uri : String
}

///|
pub fn authentication_scheme(
  scheme_type : String,
  name : String,
  description? : String = "",
  spec_uri? : String = "",
  documentation_uri? : String = "",
) -> AuthenticationScheme {
  { scheme_type, name, description, spec_uri, documentation_uri, }
}

///|
pub(all) struct ServiceProviderConfig {
  patch_supported : Bool
  bulk_supported : Bool
  bulk_max_operations : Int
  bulk_max_payload_size : Int
  filter_supported : Bool
  filter_max_results : Int
  change_password_supported : Bool
  sort_supported : Bool
  etag_supported : Bool
  authentication_schemes : Array[AuthenticationScheme]
}

///|
pub fn service_provider_config(
  patch_supported? : Bool = true,
  bulk_supported? : Bool = true,
  bulk_max_operations? : Int = 1000,
  bulk_max_payload_size? : Int = 1048576,
  filter_supported? : Bool = true,
  filter_max_results? : Int = 200,
  change_password_supported? : Bool = false,
  sort_supported? : Bool = true,
  etag_supported? : Bool = false,
  authentication_schemes? : Array[AuthenticationScheme] = [],
) -> ServiceProviderConfig {
  {
    patch_supported,
    bulk_supported,
    bulk_max_operations,
    bulk_max_payload_size,
    filter_supported,
    filter_max_results,
    change_password_supported,
    sort_supported,
    etag_supported,
    authentication_schemes: authentication_schemes.copy(),
  }
}

///|
pub fn service_provider_config_resource(
  config : ServiceProviderConfig,
) -> @value.Object {
  @value.object([
    @value.field(
      "schemas",
      @value.list([@value.string(service_provider_config_schema_id())]),
    ),
    @value.field("patch", supported(config.patch_supported)),
    @value.field(
      "bulk",
      @value.object_value([
        @value.field("supported", @value.boolean(config.bulk_supported)),
        @value.field(
          "maxOperations",
          @value.number(config.bulk_max_operations.to_double()),
        ),
        @value.field(
          "maxPayloadSize",
          @value.number(config.bulk_max_payload_size.to_double()),
        ),
      ]),
    ),
    @value.field(
      "filter",
      @value.object_value([
        @value.field("supported", @value.boolean(config.filter_supported)),
        @value.field(
          "maxResults",
          @value.number(config.filter_max_results.to_double()),
        ),
      ]),
    ),
    @value.field("changePassword", supported(config.change_password_supported)),
    @value.field("sort", supported(config.sort_supported)),
    @value.field("etag", supported(config.etag_supported)),
    @value.field(
      "authenticationSchemes",
      @value.list(config.authentication_schemes.map(auth_resource)),
    ),
  ])
}

///|
pub(all) struct SchemaExtension {
  schema : String
  required : Bool
}

///|
pub fn schema_extension(
  schema : String,
  required? : Bool = false,
) -> SchemaExtension {
  { schema, required, }
}

///|
pub fn resource_type_resource(
  name : String,
  endpoint : String,
  schema : String,
  description? : String = "",
  extensions? : Array[SchemaExtension] = [],
) -> @value.Object {
  let fields = base_fields(resource_type_schema_id())
  fields.push(@value.field("id", @value.string(name)))
  fields.push(@value.field("name", @value.string(name)))
  if !description.is_empty() {
    fields.push(@value.field("description", @value.string(description)))
  }
  fields.push(@value.field("endpoint", @value.string(endpoint)))
  fields.push(@value.field("schema", @value.string(schema)))
  if !extensions.is_empty() {
    fields.push(
      @value.field(
        "schemaExtensions",
        @value.list(
          extensions.map(extension => {
            @value.object_value([
              @value.field("schema", @value.string(extension.schema)),
              @value.field("required", @value.boolean(extension.required)),
            ])
          }),
        ),
      ),
    )
  }
  @value.object(fields)
}

///|
/// Represent a MoonSCIM schema as an RFC 7643 `/Schemas` resource.
pub fn schema_resource(schema : @schema.Schema) -> @value.Object {
  let fields = base_fields(schema_resource_schema_id())
  fields.push(@value.field("id", @value.string(schema.id())))
  fields.push(@value.field("name", @value.string(schema.name())))
  if !schema.description().is_empty() {
    fields.push(
      @value.field("description", @value.string(schema.description())),
    )
  }
  fields.push(
    @value.field(
      "attributes",
      @value.list(schema.attributes().map(attribute_resource)),
    ),
  )
  @value.object(fields)
}

///|
fn attribute_resource(attribute : @schema.AttributeDefinition) -> @value.Value {
  let fields : Array[@value.Field] = [
    @value.field("name", @value.string(attribute.name())),
    @value.field(
      "type",
      @value.string(attribute_type_name(attribute.attribute_type())),
    ),
    @value.field("multiValued", @value.boolean(attribute.multi_valued())),
    @value.field("required", @value.boolean(attribute.required())),
    @value.field("caseExact", @value.boolean(attribute.case_exact())),
    @value.field(
      "mutability",
      @value.string(mutability_name(attribute.mutability())),
    ),
    @value.field("returned", @value.string(returned_name(attribute.returned()))),
    @value.field(
      "uniqueness",
      @value.string(uniqueness_name(attribute.uniqueness())),
    ),
  ]
  if !attribute.description().is_empty() {
    fields.push(
      @value.field("description", @value.string(attribute.description())),
    )
  }
  if !attribute.canonical_values().is_empty() {
    fields.push(
      @value.field(
        "canonicalValues",
        @value.list(attribute.canonical_values().map(@value.string)),
      ),
    )
  }
  if !attribute.reference_types().is_empty() {
    fields.push(
      @value.field(
        "referenceTypes",
        @value.list(attribute.reference_types().map(@value.string)),
      ),
    )
  }
  if !attribute.sub_attributes().is_empty() {
    fields.push(
      @value.field(
        "subAttributes",
        @value.list(attribute.sub_attributes().map(attribute_resource)),
      ),
    )
  }
  @value.object_value(fields)
}

///|
fn auth_resource(auth : AuthenticationScheme) -> @value.Value {
  let fields : Array[@value.Field] = [
    @value.field("type", @value.string(auth.scheme_type)),
    @value.field("name", @value.string(auth.name)),
  ]
  if !auth.description.is_empty() {
    fields.push(@value.field("description", @value.string(auth.description)))
  }
  if !auth.spec_uri.is_empty() {
    fields.push(@value.field("specUri", @value.string(auth.spec_uri)))
  }
  if !auth.documentation_uri.is_empty() {
    fields.push(
      @value.field("documentationUri", @value.string(auth.documentation_uri)),
    )
  }
  @value.object_value(fields)
}

///|
fn supported(value : Bool) -> @value.Value {
  @value.object_value([@value.field("supported", @value.boolean(value))])
}

///|
fn base_fields(schema : String) -> Array[@value.Field] {
  [@value.field("schemas", @value.list([@value.string(schema)]))]
}

///|
fn attribute_type_name(value : @schema.AttributeType) -> String {
  match value {
    StringType => "string"
    BooleanType => "boolean"
    DecimalType => "decimal"
    IntegerType => "integer"
    DateTimeType => "dateTime"
    ReferenceType => "reference"
    BinaryType => "binary"
    ComplexType => "complex"
  }
}

///|
fn mutability_name(value : @schema.Mutability) -> String {
  match value {
    ReadOnly => "readOnly"
    ReadWrite => "readWrite"
    Immutable => "immutable"
    WriteOnly => "writeOnly"
  }
}

///|
fn returned_name(value : @schema.Returned) -> String {
  match value {
    Always => "always"
    Never => "never"
    Default => "default"
    Request => "request"
  }
}

///|
fn uniqueness_name(value : @schema.Uniqueness) -> String {
  match value {
    NoUniqueness => "none"
    Server => "server"
    Global => "global"
  }
}
