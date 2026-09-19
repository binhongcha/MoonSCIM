# Testing

The public behavioral seams are schema validation, filter compilation and
matching, PATCH application, query execution, Bulk planning, JSON codecs, and
protocol/discovery resource builders.
Black-box tests exercise those interfaces. White-box tests are limited to
parser recovery, graph invariants, and other conditions that cannot be observed
through a stable public result.

Run the local acceptance subset with:

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native --deny-warn
moon info
git diff --exit-code
python tools/count_moonbit_loc.py --minimum 4000
moon run examples/saas_provisioning --target native
moon run examples/hr_lifecycle --target native
moon run examples/group_sync --target native
moon run cmd/main --target native -- discover
moon run benchmarks/query_10k --target native
```

As of 2026-09-19, 99 tests pass on each of wasm, wasm-gc, JavaScript, and
Native. The suite includes normal inputs, missing/empty values, malformed
paths and expressions, type/cardinality errors, extension URNs, atomic failure,
Bulk cycles and forward references, cursor/query mismatch, duplicate JSON
attributes, resource-budget exhaustion, and protocol discovery shapes.

The 4,000-line gate counts project-owned `.mbt` files while excluding build,
registry, scratch, and VCS directories. Generated fixtures, repeated
definitions, and comments do not satisfy the effective-line policy.

## Performance checks

Query execution is intentionally an in-memory reference implementation. Before
releasing a change to filter, sort, cursor, or Bulk planning behavior, exercise
representative tenant sizes (1, 100, 10,000 resources), long conjunctions,
multi-valued attributes, the configured Bulk maximum, and codec budget edges.
Record wall time and peak memory in the release issue; do not encode
machine-specific thresholds in portable unit tests. Large production
directories should benchmark a storage-pushdown adapter separately.

`benchmarks/query_10k` is the reproducible reference workload: it creates
10,000 resources, filters 5,000 active users, performs stable sorting and
projection, and validates a 100-item page. It is a regression smoke test, not a
claim about a production database or an absolute latency guarantee.
