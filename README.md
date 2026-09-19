# MoonSCIM

[简体中文](README_zh_CN.md) · [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Testing](docs/TESTING.md)

MoonSCIM is a portable semantic core for the System for Cross-domain Identity
Management (SCIM) 2.0 standards. It gives MoonBit applications reusable schema,
validation, filtering, PATCH, pagination, Bulk, discovery, and JSON behavior
without selecting an HTTP framework, database, identity provider, or deployment
platform for them.

The library is useful wherever identities must cross a system boundary:
employee onboarding and offboarding, SaaS tenant provisioning, group and role
synchronization, education and healthcare directories, developer-organization
sync, device registries, LDAP/SCIM gateways, conformance tools, and test doubles.

## Highlights

- RFC 7643-style attribute definitions, extension schemas, registry lookup,
  cardinality/type/canonical-value checks, and operation-aware mutability.
- RFC 7644 filter lexer, precedence parser, typed evaluator, complex value
  paths, case-insensitive attribute paths, and extension-URN qualification.
- Atomic SCIM `add`, `replace`, and `remove`, including filtered updates of
  multi-valued complex attributes.
- Attribute projection, stable sorting, index pagination, and RFC 9865-style
  query-bound cursor pages.
- Bulk request validation, stable dependency ordering, cycle detection, forward
  `bulkId` references, and recursive reference substitution.
- Deterministic JSON conversion with input-size, nesting, and node budgets plus
  case-insensitive duplicate-attribute rejection.
- Standard User, Group, and Enterprise User schemas; ListResponse, Error,
  ServiceProviderConfig, ResourceType, and Schema discovery resources.
- Portable core verified on WebAssembly, WebAssembly GC, JavaScript, and Native;
  a Native CLI and three runnable end-to-end examples.

## Quick start

The project uses the current MoonBit toolchain and has no runtime package
dependency outside `moonbitlang/core`.

```sh
git clone https://github.com/oyjh0381/MoonSCIM.git
cd MoonSCIM
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run examples/saas_provisioning --target native
```

Library packages are imported independently so applications only pay for the
seams they use:

```mbt
let resource = @codec.decode_object(json_text).unwrap()
let report = @validation.validate_resource(
  @standard.standard_registry(),
  @standard.user_schema_id(),
  resource,
  @validation.Create,
)
if report.is_valid() {
  let filter = @filter.compile_filter(
    "active eq true and emails[type eq \"work\"].value co \"@example.com\"",
  ).unwrap()
  println(filter.matches(resource))
}
```

Apply an immutable, atomic update:

```mbt
let updated = @patch.apply_patch(resource, [
  @patch.replace("active", @value.boolean(false)),
  @patch.remove("title"),
]).unwrap()
```

## CLI

The CLI accepts inline JSON, which makes it convenient in CI scripts and
conformance checks. Shell quoting rules still apply.

```sh
moon run cmd/main --target native -- version
moon run cmd/main --target native -- discover
moon run cmd/main --target native -- validate '{"schemas":["urn:ietf:params:scim:schemas:core:2.0:User"],"userName":"alice"}'
moon run cmd/main --target native -- match 'active eq true' '{"active":true}'
```

Exit code `0` means success, `2` means malformed CLI/JSON/filter input, `3`
means schema-invalid input, and `4` is an unexpected serialization failure.

## Runnable scenarios

```sh
moon run examples/saas_provisioning --target native
moon run examples/hr_lifecycle --target native
moon run examples/group_sync --target native
```

- `saas_provisioning` validates a User, applies role/display-name PATCHes,
  filters and sorts it, then emits a ListResponse.
- `hr_lifecycle` decodes an HR record, performs an offboarding transition, and
  validates the before/after mutability contract.
- `group_sync` plans a forward-referencing Bulk request and resolves a new User
  identifier inside a Group membership.

## Package map

| Package | Responsibility |
| --- | --- |
| `value` | Immutable JSON-shaped values and case-insensitive objects |
| `path` | SCIM attribute and extension-URN paths |
| `schema` / `standard` | Schema metadata, registry, built-in resources |
| `validation` | Resource and transition diagnostics |
| `filter` | Compile and evaluate SCIM filters and value paths |
| `patch` | Atomic SCIM PATCH transformations |
| `query` | Projection, sorting, index and cursor pagination |
| `bulk` | Bulk validation, dependency planning, `bulkId` resolution |
| `codec` | Bounded deterministic JSON conversion |
| `protocol` | Response envelopes and discovery resources |

## Standards support

| Area | v0.1 status | Deliberate boundary |
| --- | --- | --- |
| RFC 7643 core resource model | Implemented | Host assigns IDs, timestamps, and versions |
| RFC 7644 filters | Implemented | String matching is case-insensitive unless a host adds schema-aware comparison |
| RFC 7644 PATCH | Implemented | Operates on in-memory resources; persistence is external |
| RFC 7644 Bulk | Planning/resolution implemented | HTTP execution, rollback, and rate limits are external |
| RFC 7644 discovery/messages | Implemented value builders | Routing and content negotiation are external |
| RFC 7644 index pagination | Implemented | Storage push-down is an adapter concern |
| RFC 9865 cursor pagination | Implemented continuation model | Built-in token is not a MAC; sign/encrypt at trust boundaries |
| RFC 9944 device schemas | Not yet implemented | Planned extension package |
| RFC 9967 SCIM events | Not yet implemented | Requires event transport and security profile |

MoonSCIM does not provide an HTTP server, OAuth/OIDC, TLS, authorization,
database, uniqueness transaction, audit sink, secret store, or personal-data
retention policy. These are deployment decisions, not portable SCIM semantics.
See [SECURITY.md](docs/SECURITY.md) before accepting untrusted traffic.

## Quality gates

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native --deny-warn
moon info
python tools/count_moonbit_loc.py --minimum 4000
```

The repository currently contains 87 passing tests on each of four targets and
more than 5,000 effective non-comment MoonBit lines. CI repeats formatting,
portable checking, tests, Native builds, executable examples, generated API
verification, and the 4,000-line project-scale gate.

## Project origin and compatibility

MoonSCIM is an original MoonBit implementation based on public behavior in
IETF RFC 7643, RFC 7644, and RFC 9865. It does not port or translate another
SCIM SDK. The ecosystem comparison that selected this project is recorded in
[`docs/ecosystem-review.md`](docs/ecosystem-review.md) and must be repeated
before registry publication.

The public API follows semantic versioning. Version 0.1 may still refine names
before 1.0; behavior changes are documented in [CHANGELOG.md](CHANGELOG.md).

## License

Apache License 2.0. Normative and comparative sources are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
