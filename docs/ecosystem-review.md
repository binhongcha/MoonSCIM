# Ecosystem review

Initial review date: 2026-09-19. Publication recheck: 2026-09-19.

## Decision

MoonSCIM was selected after comparing eight standards-oriented candidates:
SCIM, TUF, CoAP, DSSE/in-toto, BPMN, ActivityStreams, OPC UA Binary, and
SPARQL. SCIM ranked first because it combines a current ecosystem gap, broad
cross-industry demand, a standards-defined interoperability target, and a
complete 5,300–7,500 line implementation scope without requiring cryptographic
primitives, a compiler change, or production networking.

## Mooncakes.io queries

The official `/api/v0/search` endpoint was queried with:

- `SCIM`, `SCIM 2.0`, and `System for Cross-domain Identity Management`;
- `RFC 7643`, `RFC 7644`, and `RFC 9865`;
- `identity provisioning`, `user provisioning`, and `directory sync`;
- `SCIM filter`, `SCIM patch`, `SCIM bulk`, and `SCIM cursor pagination`.

No query returned a direct SCIM implementation. The closest package was
`hbYlj/moonldap`, an LDAPv3 client and BER codec. LDAP and SCIM can be bridged,
but LDAP does not provide SCIM's JSON resource model, schema characteristics,
filter language, PATCH semantics, Bulk messages, or discovery resources.

Generic JSON Schema and JSON Patch packages are also not substitutes. SCIM
attributes have case, mutability, returned, uniqueness, cardinality, and URN
extension semantics, while SCIM PATCH paths deliberately differ from JSON
Pointer and RFC 6902 array operations.

## Local portfolio comparison

The surrounding workspace already contains projects for BDDs, curve fitting,
external sorting, structure-aware fuzzing, HTTP caching, IPFIX, deterministic
distributed simulation, MIME, vector tiles, OCI images, and tus uploads.
MoonSCIM shares no core object or computation with those projects. In
particular, it avoids the supply-chain theme of MoonOCI, binary protocol codec
theme of MoonIPFIX, state-space exploration theme of MoonLab, and parser test
infrastructure theme of MoonGrammata.

## Demand and currency

RFC 7643 defines the extensible User and Group resource model. RFC 7644 defines
querying, filters, PATCH, Bulk, discovery, and protocol messages. RFC 9865
added cursor pagination in October 2025. RFC 9944 added device provisioning
schemas and RFC 9967 added asynchronous SCIM events in May 2026. The recent
extensions show continuing standardization beyond traditional employee
accounts.

Representative consumers include enterprise identity providers, SaaS vendors,
HR lifecycle automation, multi-cloud directories, education and healthcare
tenancy, developer-platform organization sync, device enrollment, test tools,
and LDAP-to-SCIM gateways.

## Recheck gate

Immediately before release, the official API queries above were repeated. The
SCIM name, full name, RFC 7643/7644/9865, SCIM filter/PATCH/Bulk/cursor terms,
and identity/user provisioning returned no matching SCIM package. The API's
fallback results for `identity provisioning` and `directory sync` had zero
matched package count or matched filesystem words only. `hbYlj/moonldap@0.3.0`
remains the nearest project and still describes an LDAPv3/ASN.1 BER client,
not SCIM JSON schema, PATCH, Bulk, discovery, or RFC 9865 behavior.

No mature, functionally overlapping SCIM core was found in this recheck. A
future release must repeat the same search; renaming alone is never an adequate
response to a newly discovered overlap.
