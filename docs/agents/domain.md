# Domain documentation

MoonSCIM uses a single-context domain model. The root [`CONTEXT.md`](../../CONTEXT.md)
defines canonical terms; architecture decisions live in [`docs/adr`](../adr).
Changes to Resource, Schema, Attribute Path, Value Path, Filter, Patch
Operation, Bulk Operation, Projection, or Diagnostic semantics must update the
context document and add or supersede an ADR when they change a boundary.
