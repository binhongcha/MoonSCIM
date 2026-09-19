# MoonSCIM

MoonSCIM models the portable semantics used to exchange and transform SCIM
identity resources independently of transport, authentication, and storage.

## Language

**Resource**:
A JSON-shaped identity object governed by one base Schema and zero or more extension Schemas.
_Avoid_: Record, entity, document

**Schema**:
A named collection of Attribute Definitions identified by a URI.
_Avoid_: JSON Schema, class, table schema

**Attribute Definition**:
The declared type, cardinality, mutability, returned behavior, case behavior, and uniqueness of one Resource attribute.
_Avoid_: Field descriptor, property metadata

**Resource Type**:
The discoverable contract that associates an endpoint and base Schema with optional Schema Extensions.
_Avoid_: Schema, class

**Attribute Path**:
A case-insensitive reference to an attribute, optionally qualified by a Schema URI and sub-attribute.
_Avoid_: JSON Pointer, array index

**Value Path**:
An Attribute Path whose multi-valued complex attribute is narrowed by a Filter before a sub-attribute is selected.
_Avoid_: JSONPath, array predicate

**Filter**:
A compiled SCIM boolean expression evaluated against a Resource or complex attribute value.
_Avoid_: SQL predicate, policy

**Patch Operation**:
One SCIM add, replace, or remove transformation applied atomically as part of a Patch Request.
_Avoid_: JSON Patch operation, mutation command

**Bulk Operation**:
One protocol request inside a Bulk Request, optionally referring to an earlier operation through a bulkId.
_Avoid_: Batch row, transaction statement

**Projection**:
The selection of attributes returned to a caller after schema returnability and requested attributes are combined.
_Avoid_: Serialization, filtering

**Diagnostic**:
A stable, structured explanation that identifies an invalid resource, expression, path, operation, or protocol message.
_Avoid_: Log line, exception text
