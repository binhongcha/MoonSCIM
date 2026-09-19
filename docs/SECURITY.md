# Security model

MoonSCIM processes identity data but is not an identity security boundary by
itself. Deployments must add transport, authentication, authorization,
persistence, and operational controls appropriate to their threat model.

## Defenses implemented in the core

- JSON decoding is bounded by configurable input characters, nesting depth,
  and total value nodes before a MoonSCIM value tree is allocated.
- Object keys that collide case-insensitively are rejected, preventing one
  component from validating `userName` while another consumes `USERNAME`.
- Malformed paths, filters, cursor tokens, schemas, Bulk dependencies, and
  PATCH targets return typed errors rather than partial mutations.
- PATCH is atomic at the value level: a failed later operation exposes no
  partially updated result.
- Public collection accessors return copies, reducing accidental shared-state
  mutation across requests.
- Bulk cycles and unresolved references are rejected before execution.

## Host responsibilities

An Internet-facing service must provide all of the following:

1. TLS and authenticated clients, normally OAuth bearer tokens or mTLS.
2. Per-resource and per-attribute authorization before reads and writes.
3. Request-body, request-rate, timeout, and concurrency limits in addition to
   codec budgets.
4. Transactional uniqueness for attributes such as `userName`, and optimistic
   concurrency for `meta.version`/ETags.
5. Signed or encrypted RFC 9865 cursor tokens. The built-in deterministic token
   only detects query mismatch; it is not a message authentication code.
6. Audit events that avoid logging passwords, bearer tokens, or unnecessary
   personal data; retention and deletion policies must follow local law.
7. Correct filtering of `writeOnly` values from responses and enforcement of
   `returned` behavior in the application response path.
8. Database query parameterization if a compiled filter is translated into SQL
   or another query language. Never concatenate user filter text.

## Known semantic boundaries

- The standalone filter evaluator compares strings case-insensitively. A host
  that needs custom-schema `caseExact=true` behavior must use a schema-aware
  comparison adapter.
- Validation describes resource shape and transitions; it cannot prove access
  rights, cross-resource references, global uniqueness, or storage durability.
- Bulk planning does not create a distributed transaction and does not execute
  `failOnErrors`; the adapter controls commit/rollback behavior.
- JSON budgets are measured in MoonBit string code units, not HTTP wire bytes.
  The HTTP layer should enforce a byte limit before UTF-8 decoding.
- The package does not normalize Unicode identifiers. Deployments should define
  normalization, spoofing, and confusable-character policy for login names.

## Safe deployment checklist

- Keep default codec budgets or reduce them for the endpoint's expected shape.
- Cap filter source length, collection count, Bulk operations, and PATCH count.
- Apply authorization before projection so hidden attributes cannot affect
  observable sorting or error differences.
- Sign cursor state and bind it to tenant, subject, expiry, and query.
- Treat SCIM passwords as secrets even when the downstream provider hashes
  them; never include them in logs or error detail.
- Run all negative and cross-target tests after changing a schema or adapter.

Security reports should be sent privately to the maintainer before opening a
public issue. Do not attach real identities, access tokens, or production SCIM
payloads to a report.
