# Testing

The public behavioral seams are schema validation, filter compilation and
matching, PATCH application, query execution, Bulk planning, and JSON codecs.
Black-box tests exercise those interfaces. White-box tests are limited to
parser recovery, graph invariants, and other conditions that cannot be observed
through a stable public result.

Run the local acceptance subset with:

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
moon build --target native --deny-warn
moon info
git diff --exit-code
python tools/count_moonbit_loc.py
```

The 4,000-line CI gate is intentionally red during early development. It is a
final scale guard, not permission to add repeated definitions, generated
fixtures, or low-value code.
