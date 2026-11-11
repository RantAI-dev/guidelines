# TODO(fill): project name

TODO(fill): two or three sentences. What this is, who calls it, what the moving parts are.

## Commands

| What | Command |
|---|---|
| Everything, before any handoff | `scripts/check.sh` |
| Only the stacks you touched, while iterating | `scripts/check.sh --changed` |
| One test | TODO(fill): for example `bun test path/to/file.test.ts -t "name"` |
| Run it locally | TODO(fill) |

## Where code lives

TODO(fill): one line per top-level area, and which way dependencies point. For example:

- `src/contracts/` — schemas and types that cross a boundary. Imports nothing else from this repo.
- `src/features/<slice>/` — one folder per capability. `index.ts` is the slice's public surface.
- `tests/contract/` — behaviour other teams build against. Listed in `.agents/protected-paths`.

## Rules the gate enforces

`scripts/check.sh` and CI fail on these. A rule that exists only as a sentence here will be broken.

1. TODO(fill): one line per lint, type or boundary rule that surprises newcomers, with the command
   that reports it.

## Conventions

The same in every RantAI repository. The full list is `docs/conventions.md`; read it before you add
an endpoint, an error, a log line, a config variable or a table. The ones broken most often:

- Every error response is `{ "error": { "code", "message", "requestId" } }`, built by one function.
- A `code` is a row of `.agents/error-codes.tsv`. New code: add a row, run
  `scripts/error-codes.sh --write`. Never rename or remove a row. Its status comes from the table.
- No internal text in a message: no exception text, SQL or upstream response. Log it instead.
- JSON fields are `camelCase`; times are `2026-11-11T08:30:00.000Z` in fields ending `At`.
- A list returns `{ "data": [...], "nextCursor": ... }`, never a bare array.
- Tests assert on the status and the `code`, not on message text.
- Commit subject: `type(scope): summary`.

## Working agreements

1. **Evidence, not claims.** "Green" means you ran `scripts/check.sh` after your last edit and can
   quote its last line. Anything you did not run is `not verified`.
2. **Never weaken a gate to get green.** No deleted or skipped tests, no suppression without a reason
   on the same line, no edits to anything in `.agents/protected-paths`. If a test is wrong, say so
   and stop.
3. **When the plan and the code disagree, do not pick a side silently.** Stop and report, or follow
   the code or contract test and list it under DEVIATIONS in your handoff.
4. **Stay in scope.** Change only the paths your task names. Everything else you noticed goes in the
   handoff.
5. **Proof depends on the change.** Logic or data: a test that failed before and passes now, in
   the module's existing test file. Visual: before and after captures. Server only: the test plus a
   short runtime transcript. Nobody will read your diff; the proof is what gets read.
6. **Comments say why, or nothing.** One line for a constraint the code cannot show. If a line looks
   wrong but is right, say why at that line, or the next reader will "fix" it.
7. **Search before you write.** Look for an existing helper first. A second copy is a review finding.
   New code goes in a file named for what it does, not at the bottom of the nearest big one. The
   gate fails a source file over 600 lines (1,000 for Rust), and a file already over that may only
   shrink.
8. **No new dependency** without the owner's approval. Say why you need it in the handoff.

## Traps

Things that went wrong in this repo. Add a line when the same mistake happens twice. Delete the line
once a lint rule or a test catches it.

- TODO(fill)

## Roles

- You are the long-lived thread connected to the tracker: you are the **desk**. Load the `desk` skill.
- Another agent gave you a brief: you are the **worker**. Follow the brief and end with its handoff.
- The desk, or a person, asked you to plan, delegate or review one feature: you are the **lead**.
  Load the `orchestrate` skill first.
- You were asked to bring this repository up to the guidelines, or to clean it up: load the
  `adopt-guidelines` skill.
- You were asked to move code to another language: load the `port-code` skill.
