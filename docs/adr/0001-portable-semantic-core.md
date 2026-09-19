# Keep SCIM semantics portable and adapter-free

MoonSCIM implements schema validation, filters, PATCH, query semantics, and Bulk planning as deterministic portable modules; HTTP, authentication, clocks, identifiers, and storage remain host-provided adapters. This preserves reuse across MoonBit backends and prevents a particular Web framework or database from becoming part of the library interface, at the cost of requiring applications to supply their own integration layer.
