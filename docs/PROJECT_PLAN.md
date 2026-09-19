# Project plan

MoonSCIM is developed as vertical, independently testable slices. Every slice
must pass `moon check`, its relevant tests, and formatting before it is
committed.

## Milestones

1. Module metadata, glossary, licensing, ecosystem evidence, and CI.
2. Portable value model with case-insensitive object lookup.
3. Attribute and schema model with registry lookup.
4. Validation diagnostics and operation-aware mutability checks.
5. Attribute-path parser with extension-URN qualification.
6. Filter lexer, precedence parser, AST, and typed evaluator.
7. Complex multi-value value-path evaluation.
8. PATCH add, replace, remove, and atomic request application.
9. Attribute projection, sorting, index pagination, and cursor models.
10. Bulk dependency planning, cycle diagnostics, and bulkId substitution.
11. Standard User, Group, and Enterprise User schemas.
12. Protocol message codecs, discovery models, CLI, and examples.
13. Conformance fixtures, fuzz/property checks, performance baselines, docs,
    proposal, release metadata, and final acceptance review.

## Current status

Milestones 1–12 are implemented. Milestone 13 has completed local functional
tests, runnable scenarios, documentation, proposal, release metadata, the
scale/history gates, and the final live mooncakes.io collision scan. The
remaining release-only steps are the public GitHub push with CI evidence,
Gitlink synchronization, and mooncakes.io publication; they intentionally occur
after local acceptance.

## Quantitative gates

- More than 4,000 effective non-comment MoonBit lines from real functionality.
- More than 20 meaningful commits, each tied to a reviewable milestone.
- Portable checks and tests on wasm-gc, JavaScript, and Native.
- At least three runnable scenarios: SaaS provisioning, HR lifecycle update,
  and group/device synchronization.
- Public-interface tests for every agreed seam and negative tests for malformed,
  ambiguous, oversized, and type-invalid inputs.
- No HTTP, authentication, database, or personal-data dependency in the core.

GitHub push, Gitlink synchronization, and mooncakes.io publication occur only
after the local acceptance review passes.
