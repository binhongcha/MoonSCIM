# Architecture

## Design goal

MoonSCIM is a deep, portable semantic module: an application supplies identity
data and policy, MoonSCIM returns deterministic values or structured errors.
Network listeners, authentication, persistence, clocks, identifier generation,
and authorization stay outside the package boundary.

```text
HTTP / queue / file adapter
          |
      bounded codec
          |
  protocol value builders
          |
 schema ─ validation ─ patch ─ filter ─ query ─ bulk
          |                      |
        path                  immutable value
          \______________________/
```

The direction is intentional. The `value` and `path` packages know nothing
about protocol operations. Higher packages compose them, and no portable package
imports a Native-only adapter.

## Module responsibilities

### Value and path

`value` owns one JSON-shaped immutable representation. Object lookup is
case-insensitive because SCIM attribute names are case-insensitive, while the
first spelling and insertion order are retained for deterministic output.
Copies returned by public accessors prevent callers from mutating internal
arrays. `path` parses plain, sub-attribute, and extension-URN paths without
pretending that they are JSON Pointer expressions.

### Schema and validation

`schema` expresses type, cardinality, requiredness, `caseExact`, canonical
values, mutability, returned behavior, uniqueness, references, and nested
attributes. A registry resolves base and extension paths. `validation` walks
resources and before/after transitions, returning stable diagnostics rather
than throwing. Uniqueness across stored resources is deliberately not checked
because that needs a transactional repository.

### Filter, PATCH, and query

`filter` compiles source text into an AST before evaluation. Boolean precedence
and value-path scoping are represented in the AST rather than inferred during
matching. `patch` applies every operation to temporary immutable values and
returns no partial result if any operation fails. `query` composes filtering,
stable sorting, projection, and pagination over an in-memory collection.

### Bulk and protocol

`bulk` separates dependency planning from request execution. It validates the
operation model, finds recursive `bulkId` references, produces a stable
topological order, and substitutes server-assigned identifiers. A host remains
responsible for HTTP dispatch, transactions, and `failOnErrors` execution.
`protocol` builds standard response/discovery resources while `codec` converts
them to or from bounded JSON.

## Complexity

Let `n` be input characters, `a` attributes in a resource, `r` candidate
resources, `e` filter AST nodes, `p` PATCH operations, and `b` Bulk operations.

| Operation | Time | Extra space | Notes |
| --- | --- | --- | --- |
| JSON structural scan and decode | `O(n)` | `O(n)` | Enforces limits before value-tree construction |
| Path parse | `O(n)` | `O(n)` | URN qualification is a linear delimiter scan |
| Schema/resource validation | `O(a × s)` worst case | `O(a)` | `s` is schema attribute count; current registry uses small ordered arrays |
| Filter compile | `O(n)` | `O(n)` | Lexer plus precedence parser |
| Filter match | `O(e × a)` worst case | `O(e)` | Multi-valued paths also visit selected list elements |
| PATCH request | `O(p × a)` typical | `O(a)` per immutable update | Atomicity favors copies over in-place rollback |
| In-memory query | `O(r × e + r log r)` | `O(r)` | Sorting dominates after filtering |
| Bulk planning | `O(b² + v)` | `O(b + v)` | Ordered-array lookup keeps behavior simple; `v` is visited value nodes |

For very large directories, applications should translate the compiled filter,
sort, projection, and pagination request into their database query rather than
materializing every resource. The in-memory executor is intended for adapters,
tests, smaller tenants, and reference behavior.

## Extension points

- Register custom RFC 7643 extension schemas in a `SchemaRegistry`.
- Translate `FilterExpression` into a database or search-engine predicate.
- Sign or encrypt cursor tokens in the transport adapter.
- Map structured diagnostics and errors to application logging/telemetry.
- Add HTTP, persistence, authorization, uniqueness, and audit adapters without
  changing the semantic core.

## Decisions

Architecture decisions live in [`adr/`](adr/). The root [`CONTEXT.md`](../CONTEXT.md)
defines the ubiquitous language used in APIs and documentation.
