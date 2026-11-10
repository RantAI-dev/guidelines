# orderdesk

Order pricing, storage and export for a small shop backend. TypeScript, run with Bun.

## Commands

| What | Command |
|---|---|
| Everything (run before handoff) | `bun run check` |
| One test file while iterating | `bun test src/features/<slice>/<file>.test.ts` |
| Types / lint / boundaries alone | `bun run typecheck` · `bun run lint` · `bun run boundaries` |
| Auto-format | `bunx biome check --write .` |

## Where code lives

- `src/contracts/` — schemas, branded ids, `Result`. Imports nothing from `src/features/`.
- `src/features/<slice>/` — one folder per capability. `index.ts` is the slice's public API.
  A slice imports another slice only through that slice's `index.ts`.
- `tests/contract/` — the public behaviour other teams build against. Owned by the product owner.

## Rules

1. Errors are values. Code under `src/features/` returns `Result<T, E>` from `src/contracts/result.ts`
   and never uses `throw`. `bun run boundaries` fails on a `throw`.
2. Raw strings from outside are parsed into branded types at the edge of a slice (`OrderId.safeParse`).
3. Never edit `tests/contract/**`, and never weaken a test, lint rule or the boundary script to get green.
4. If the plan disagrees with the code or with a contract test, do not pick a side silently. Either stop
   and report, or follow the contract test and list it under `DEVIATIONS` in the handoff.
5. A bug fix starts with a test that fails for that bug, in the slice's existing test file.
6. Stay inside the paths the task names. Anything else you think needs changing goes in the handoff.
7. "Green" means you ran `bun run check` after your last edit and read its output. Otherwise write
   `not verified`.
