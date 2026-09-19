# Contributing

MoonSCIM welcomes standards-focused fixes, tests, adapters, and extension
schemas. Before changing behavior, cite the relevant RFC section or describe
the interoperability problem in an issue.

## Development flow

1. Keep transport, authentication, storage, and policy dependencies outside the
   portable core unless an accepted ADR changes the boundary.
2. Add a failing black-box test through a public seam, then implement the
   smallest behavior that makes it pass.
3. Include malformed, boundary, and large-input cases for parsers or codecs.
4. Update `CONTEXT.md`, an ADR, and the support matrix when terminology or scope
   changes.
5. Run the complete quality gate before opening a pull request.

```sh
moon fmt
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target native --deny-warn
moon info
git diff --check
python tools/count_moonbit_loc.py --minimum 4000
```

Generated `pkg.generated.mbti` files are committed. Run `moon info`, inspect the
public API diff, then include expected interface changes in the same commit.

Use focused commits with an imperative Conventional Commit summary such as
`feat(filter): support nested value paths` or `fix(codec): reject duplicate
extension keys`. New third-party code, generated fixtures, and copied examples
must include license and provenance review. Real personal data is never accepted
as a test fixture.
