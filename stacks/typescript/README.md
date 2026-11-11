# TypeScript

What `scripts/check.sh` expects from `package.json`:

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "biome check .",
    "boundaries": "bun scripts/check-boundaries.ts",
    "test": "bun test"
  }
}
```

- **Compiler flags that pay for themselves:** `strict`, `noUncheckedIndexedAccess`,
  `exactOptionalPropertyTypes`, `verbatimModuleSyntax`. See `tsconfig.strict.json`.
- **Lint:** Biome or oxlint, with `noExplicitAny` and `noNonNullAssertion` as errors. Both run in
  milliseconds, which matters when an agent runs them after every edit.
- **Boundaries:** `check-boundaries.ts` is a 50-line script: no `throw` in feature code, contracts
  import nothing from features, a slice imports another slice only through its `index.ts`. Each
  message says how to fix the violation. Copy it and edit the rules; when it outgrows a script,
  move to `dependency-cruiser` or lint `no-restricted-imports`.
- **Errors:** `api-error.ts` builds the one error body from the generated `error-codes.ts`. Add
  `@emit ts <path>` to `.agents/error-codes.tsv`, run `scripts/error-codes.sh --write`, and copy
  the helper beside the result. The generated file carries its own formatter-ignore comments.
- **Dead code:** add `knip` to the `lint` script once the project has more than a few packages.
- **Public surface:** one test per package that lists its exports, so removing one fails a test
  instead of surprising another team.
