# MoonSCIM

MoonSCIM is a portable MoonBit implementation of the semantic core of the
System for Cross-domain Identity Management (SCIM) 2.0 standards. It is built
for applications that need interoperable identity provisioning without tying
their domain logic to a particular HTTP framework, database, identity provider,
or deployment target.

The project is under active development. Its planned public seams are:

- schema-aware resource validation for RFC 7643 core and extension schemas;
- RFC 7644 filter compilation and evaluation, including value paths;
- SCIM-specific attribute paths and PATCH add, replace, and remove semantics;
- deterministic projection, sorting, index pagination, and cursor models;
- Bulk request dependency planning and `bulkId` reference substitution;
- protocol message codecs and standard User, Group, and Enterprise User schemas.

## Why this project

SCIM is used to automate account and group lifecycles between identity
providers, HR systems, enterprise directories, and SaaS products. A reusable
semantic core supports employee onboarding and offboarding, multi-tenant
provisioning, group synchronization, device enrollment, test harnesses, and
directory bridges while keeping transport, authentication, storage, and policy
choices in the host application.

Mooncakes.io was searched on 2026-09-19 using `SCIM`, the standard's full name,
RFC numbers 7643 and 7644, and operation terms such as filter, PATCH, Bulk, and
cursor pagination. No directly overlapping package was found. The nearest
published project, `moonldap`, implements LDAPv3 and BER rather than SCIM's
JSON resource model and protocol semantics. This search is repeated before
publication because registry contents can change.

## Scope

MoonSCIM implements standards-driven, deterministic transformations over
in-memory values. Version 0.1 intentionally does not implement an HTTP server,
OAuth/OIDC, TLS, a production database, access control, or storage of personal
information. Those concerns belong behind host-application adapters.

The portable core targets `wasm-gc`, JavaScript, and Native. A small Native CLI
and runnable examples will be added as integration and conformance tools.

## Development

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon info
```

## Standards and licensing

The implementation is original MoonBit code derived from public behavior in
IETF RFC 7643, RFC 7644, and RFC 9865. No third-party SCIM implementation is
ported or translated. MoonSCIM is licensed under Apache License 2.0.

See `THIRD_PARTY_NOTICES.md` for normative and comparative sources and
`docs/ecosystem-review.md` for the project-selection evidence.
