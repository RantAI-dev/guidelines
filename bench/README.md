# bench

A small, repeatable test of coding agents on the kind of work we delegate. It answers three
questions with runs instead of opinions: which worker model, does our brief and AGENTS.md wording
work, and does a reviewer find what it should.

Results so far: [results/2026-11-10.md](results/2026-11-10.md).

## Layout

```
fixture-ts/     a small TypeScript + Bun repo: contracts, two feature slices, a boundary check
fixture-rust/   a small Rust crate with strict clippy lints
fixture-port/   a TypeScript function, an oracle that runs it, and a Rust crate to port it into
tasks/<task>/   brief.md (what the worker is told), overlay/ (files added to the fixture),
                hidden/ (tests the worker never sees), reference/ (a solution that passes them)
harness/        setup-run.sh and grade.sh
results/        one file per run date
```

## Run it

```bash
# 1. Make a fresh repo for one model on one task. Prints the brief.
bench/harness/setup-run.sh T1 haiku > /tmp/brief.txt

# 2. Hand the brief to the model. In T3 Code: delegate_task, role "implementation",
#    task = the brief text, target = the model under test. Wait for it to finish.

# 3. Grade. Prints one JSON line.
bench/harness/grade.sh T1 haiku
```

Tasks: `T6` port a function from TypeScript to Rust against an oracle, `T1` feature slice, `T2a`/`T2b` bug fix with a public export that has or lacks a reason,
`T3` plan that conflicts with a protected test, `T4` Rust, `T5a`/`T5b` bug fix with an odd special
case that has or lacks a reason. Run directories go to `/tmp/rantai-bench/runs`; set `BENCH_RUNS`
to move them.

`grade.sh` copies the run, adds the hidden tests to the copy and reports: the repo's own check,
hidden tests passed, files outside the brief's scope, protected files touched, seconds to the last
commit, and per-task facts such as whether the fence survived.

The review task is in `tasks/R-review/`: a diff with four planted plan violations that passes its
own tests. Apply `buggy/` on top of a T1 run directory, commit, and give a reviewer the review brief
from `template/.agents/skills/orchestrate/review-brief.md`.

## Rules for using it

- **Run each cell at least three times** before you quote a rate. The first results file has one
  run per cell and says so.
- **Compare against a baseline on the same day**, not against an old number. Routes and harnesses
  change under you.
- **Check a new task against its reference first.** The unsolved fixture must fail the hidden tests
  and the reference must pass them all. `setup-run.sh <task> ref` then apply `reference/`.
- **Add tasks from your own history.** Take a merged pull request, check out its parent, write the
  brief from the ticket, and use the tests from the real fix as hidden tests. Tasks like that are
  the only way to learn how a model does on your code.
- **Never put client code or data in a task.** Rewrite the case in the fixture's domain.
- **Add a case before you fix a prompt.** When a brief or AGENTS.md wording fails in real work,
  reproduce it here first, then change the wording, then show the case passes.

## Cost

Every run is a worker session on someone's plan. The first day's bench, about fifty sessions, used
up a monthly OpenCode Go allowance. Run a handful of cells, not the whole grid, and agree the
budget with the owner first.

## Known limits

- The fixtures are tiny. Nothing here tests navigation in a large repository.
- `fixture-rust` ships no `Cargo.lock`, so a build leaves an untracked file. The grader ignores it.
- Token counts are not captured, because T3 Code's task results do not carry them.
