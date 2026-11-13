# Engineering rules

How we write code that a person or an agent can change without breaking it. Each rule says what to
do, how it is enforced, and how strong the evidence is. Sources are in [sources.md](sources.md).

Evidence tags:

- **measured** — a study or benchmark with numbers.
- **reported** — a team describing what worked for them. Useful, not proof.
- **bench** — our own runs in [bench/results](../bench/results/2026-11-10.md).
- **judgement** — no evidence found either way. This is our call, and we say so.

The one idea behind all of it: **a rule that is only written down will be broken; a rule a script
checks will not.** Agents follow instructions most of the time. Most of the time is not good enough
for the things that matter.

## Structure

**1. One place for everything that crosses a boundary.** Schemas for requests, responses, events
and stored records live in one contracts package or folder that imports nothing else from the repo.
Change the contract first; the compiler then lists what else must change.
*Enforced by* an import rule. *Evidence:* reported (T3 Code's `packages/contracts`, our Lakehouse
`contracts → clients → services → features → app`). One small measured result: typed contracts
raised API route coverage from 33% to 100% for the weakest model tested, and made no difference
for the strongest.

**2. Group code by what changes together, and keep I/O at the edge.** For application code that
means a folder per capability with one public `index`. For a service it means a pure core, ports,
adapters and one composition root, which is how `rantai-kb` is built. These are the same idea at two
sizes, not rivals.
*Evidence:* judgement. We found no study comparing vertical slices with layers for agents. T3 Code
itself is organised by package and domain folder, not by feature slice.

**3. Pick one dependency direction and have a script enforce it.** Write the direction in one line
of AGENTS.md. The check's error message must say how to fix the violation, because the agent reads
the message and acts on it.
*Evidence:* reported, twice and independently. OpenAI: "we write the error messages to inject
remediation instructions into agent context". T3 Code's lint rules carry the comment "Agents read
this message and act on it".

**4. Transports stay thin.** An HTTP handler, RPC handler, CLI command or MCP tool decodes input,
calls one service method and maps the error. Logic in a handler is missing from every other entry
point. *Evidence:* reported (T3 Code).

**5. Prefer boring technology where cheap models write the code.** A cheap model knows React,
axum, sqlx and zod well. It knows last month's major version of a niche library badly, and it will
invent the API. When you must use such a library, put a read-only copy of its source or docs in
`.repos/` and point AGENTS.md at it, as T3 Code does for Effect.
*Evidence:* measured for docs-in-context (Vercel: 53% to 100% pass rate on new framework APIs once
a docs index was in AGENTS.md). Do not adopt Effect because T3 Code uses it: they vendor its source
precisely because models get it wrong.

**6. Failure is visible in the signature.** Domain code returns a typed error (`Result<T, E>` in
Rust, a discriminated union in TypeScript). `throw` and `panic!` are for bugs. A five-line `Result`
type is enough; this does not need a framework. What the error looks like once it leaves the
process is fixed for every repository: see [conventions.md](conventions.md).
*Enforced by* lint: no `throw` in domain code, no `unwrap`/`expect` outside tests. *Evidence:*
judgement. We found no study that typed errors help agents.

**7. Parse at the edge.** Raw input becomes a typed value once, where it enters. Brand the ids that
could be confused with each other (`TenantId`, `DocumentId`). *Evidence:* judgement.

**8. Search before you write, and measure duplication.** Do not build an abstraction before its
third use. But agents duplicate by default: across 623M changed lines, copy-pasted lines rose from
9.4% to 15.7% and refactored ("moved") lines fell from 21% to 3.8% over about four years to 2026.
"Tolerate duplication" with no detector becomes drift.
*Enforced by* a dead-code tool (`knip`, `cargo machete`, `vulture`) in the gate and a review
finding for a second copy of an existing helper. *Evidence:* measured, observational (GitClear).

**9. A source file stays under 600 lines, or 1,000 for Rust, and the gate enforces it.** Test files
get twice that. A Rust file is counted up to its inline `#[cfg(test)]` module.
Generated code, vendored code, migrations and fixtures are not counted. A file that is already over
the limit is frozen at its current length: it may shrink and may never grow.

An agent adds code where code already is. Each addition looks reasonable, nothing fails, and one
file reaches 30,000 lines. That has happened to us more than once. A warning does not stop it; a
failing check does. The check's message says how to split: move one cohesive part into its own
module, named for what it is. Cutting a file at line 600 into "part 2" is not a split.
*Enforced by* `scripts/file-size.sh`, inside `scripts/check.sh`. *Evidence:* our own experience for
the problem; judgement for the number. Nothing supports a tight 150–300 line cap. T3 Code, which
has no rule, has a median of 103 lines, 159 files over 1,000 and one of 14,720. OpenAI's team lints
file size. Healthier code has been measured to cost agents fewer tokens and break less often, with
file size explaining part of that. Set `FILE_MAX_LINES` per project if 600 does not fit.

Rust gets its own number because Rust files really are longer: a type, its impls and its unit tests
live together. We measured the non-test Rust files of seven projects on 10 November 2026, counting
lines before the inline test module:

| Project | Files | Median | 90th percentile | Over 600 | Over 1,000 | Longest |
|---|---|---|---|---|---|---|
| rust-analyzer | 1,404 | 51 | 574 | 8.8% | 4.6% | 6,649 |
| tokio | 463 | 110 | 603 | 10.2% | 5.8% | 2,736 |
| ruff | 1,889 | 131 | 681 | 11.5% | 6.5% | 13,800 |
| ripgrep | 82 | 166 | 790 | 14.6% | 7.3% | 2,194 |
| uv | 648 | 159 | 922 | 16.8% | 8.5% | 7,725 |
| bun (ported to Rust by agents) | 4,057 | 198 | 1,210 | 21.4% | 12.4% | 10,702 |
| deno | 890 | 261 | 1,364 | 24.7% | 14.4% | 9,995 |
| our rantai-kb | 162 | 201 | 753 | 15.4% | 7.4% | 2,388 |

A 600-line limit would fail one Rust file in ten even in the most carefully kept of these. At 1,000
it fails about one in twenty there, which is the tail a limit is for. Bun and Deno show where no
limit leads: one file in eight over 1,000 lines, and several past 10,000.

## The gate

**10. One script is the gate.** `scripts/check.sh` runs format, lint, types, boundary rules and
tests. The pre-commit hook runs its fast subset, a worker runs it before handoff, the lead runs it
again, and CI runs it again. If CI needs a step that is not in the script, the step goes in the
script. *Evidence:* reported (T3 Code's `check:changed`, our Lakehouse verification block).

**11. A change runs only the checks it can break.** The repository is split into parts: a stack to
start with, then one crate or package group each. `scripts/check.sh --changed` runs the parts the
changed files belong to, and a pull request's CI does the same, one job per part, side by side. A
commit that touches no Rust runs no cargo; a change inside one crate does not test the other nine.

The selection fails closed. A file every part depends on (the workspace manifest and lock file,
`scripts/`, `.github/`, migrations, a core crate) runs every part, and so does a file no part claims.
Only paths listed as affecting nothing, such as documentation, run no part. A pull request with the
label `ci:all-parts`, every push to `main`, a manual run and a nightly run check everything, so a
part that a wrong path rule left out fails within a day, not at release. Branch protection requires
one check, `ci-required`, which passes only if every selected part passed.

The split only pays if the code allows it. A file that every feature edits, such as one route table
or one policy table for the whole service, belongs to every part, so every change that touches it
runs everything. Let each module register its own routes and rules, and keep the files everything
depends on few and small. *Evidence:* reported. In our Lakehouse repository on 13 November 2026, one
full CI run was 42 jobs and spent longer waiting for a runner than running (415 job-minutes queued
against 253 running). Scoping the acceptance gates by path would have run none of 25 gates for some
of the last 27 merges, but most Rust pull requests still ran all 25, because they touched the
shared route and policy files. Splitting those files is that repository's next step.

**12. The gate has a time budget: 2 minutes while iterating, 10 for the full gate, 15 in CI.**
The budget is for a run with warm caches. `scripts/check.sh --changed` is the first number,
`scripts/check.sh` the second, each CI job the third. The parts run side by side, so the slowest
part sets the run's time.

A slow gate costs more with agents than it did with people, for three reasons. The gate runs at
least three times for every change: the worker before handoff, the lead, then CI. Nobody reads the
diff, so the gate is the only feedback there is. And an agent's shell has limits: in Claude Code as
we run it, a foreground command gets 2 minutes by default and 10 at most. A check that fits inside
those two numbers simply runs. A longer one has to go to the background, and an agent that cannot
wait for a result is tempted to report without it.

The budget shapes the code, and that is intended:

- **Small units of build.** A change should rebuild little. In Rust that means several small crates
  instead of one large one; in TypeScript, packages or project references.
- **A dependency is paid for on every build.** Its build time is part of the case for adding it.
- **Slow suites leave the gate, by the owner's decision.** End-to-end runs against real services,
  coverage, security scans, benchmarks and model evaluations go in a scheduled workflow, and a
  failure there opens a backlog row. What leaves the gate no longer protects the main branch, so
  the list is short and a person approves it.
- **Never faster by fewer tests.** `scripts/guard-diff.sh` already blocks a removed or skipped test.

*Enforced by* `timeout-minutes: 15` on every part's CI job, which fails it. Locally `scripts/check.sh` prints
`check: SLOW` and still passes, because a hard local limit would fail good changes on a busy
machine; the `sweep` skill treats that line as its first job. Workers cannot raise either number:
the gate script and the workflow are protected paths.
*Evidence:* reported, survey and judgement. Martin Fowler: "the XP guideline of a ten minute build
is perfectly within reason", and "Nothing sucks the blood of Continuous Integration more than a
build that takes a long time"; he puts slower tests in a second stage. Our own CI, wall-clock from
queued to finished over each repository's last 9 to 29 runs on 11 November 2026: a mean of 9.4
minutes in one repository, 24.8 and 27.7 in the other two, with one run of 88 minutes. The three
numbers themselves are our judgement, set by the shell limits above.

**13. Turn a repeated mistake into a check.** In order of preference: a lint rule with a test, a
test, a line in AGENTS.md "Traps". Custom lint rules used to be expensive. An agent now writes one
in minutes; T3 Code has about 35.
*Evidence:* reported (OpenAI replaced a weekly cleanup day with encoded rules plus background
refactoring agents).

**14. A suppression needs a reason on the same line.** `#[allow(..., reason = "…")]`,
`// biome-ignore <rule>: <why>`. A suppression without one fails the gate. *Evidence:* reported.

**15. Some paths are protected.** The files that define "done" and "allowed" — contract tests,
lint and type-check configuration, CI, the gate scripts — are listed in `.agents/protected-paths`.
A worker's diff that touches one is blocked by `scripts/guard-diff.sh`, and a person signs it off.
*Evidence:* measured and bench. When a task and its tests conflict, models edit the tests: 50–76%
of such tasks for frontier models in ImpossibleBench. Read-only tests, a strict instruction and
explicit permission to stop cut that to 1–9%. In our runs, with a rule saying "stop and report, or
follow the contract test and list the deviation", all six models left the contract test alone and
reported the conflict.

## Tests

**16. Test what can break.** State machines, parsing, permissions, tenancy, money, migrations,
concurrency, and the logic a bug fix changed. Not what the type checker already guarantees, not
copy text, not a mirror of mock calls. Add a row to an existing table before adding a new test.
*Evidence:* reported (T3 Code runs a review bot that only ever asks for fewer tests).

**17. A bug fix starts with a failing test.** *Evidence:* bench. With the rule in AGENTS.md, every
model that finished the bug task added the regression test.

**18. Acceptance tests come from the planner, not the author.** An author's tests share the
author's reading of the plan.
*Evidence:* bench. On the Rust task one worker misread a single sentence about saturating
arithmetic, wrote 19 passing tests that encoded the misreading, and reported "DEVIATIONS: none".
Its own check was green. It failed 2 of 13 independent tests.

**19. No sleeps, timeouts or retries in tests.** Wait on the event. A test that needs a timeout to
pass is wrong. *Evidence:* reported (T3 Code enforces this with five lint rules).

**20. "Green" is a quoted command and its count.** Anything not run is written `not verified`.
*Evidence:* reported (Anthropic: "'All tests pass' on its own tells you very little"; our Lakehouse
rule 7).

## Comments and documents

**21. Default to no comment.** Write one for a constraint, an external quirk or an invariant the
code cannot show. One line where possible, four at most. Never restate the code, narrate steps or
record history. We do not require module header blocks and we do not use `AI-NOTE` tags: a reason
is for every reader.
*Evidence:* reported. T3 Code enforces a four-line cap by lint. In its 4,078 source files there are
0 `AI-NOTE` markers, 0 `INVARIANT:` markers and 13 `@module` headers.

**22. If a line looks wrong but is right, say why at the line, and pin it with a test.**
*Evidence:* bench, small. During a tidy-up, a strange-looking special case with a one-line reason
above it was kept by 6 of 6 models. Without the comment, 3 of 6 deleted it. Two of those said so in
their handoff; the third also deleted an unused-looking public export and reported nothing. The
comment helps, but only a test makes the removal fail. For a slice's public surface, one test that
lists the exports is enough.

**23. Documents hold decisions, not descriptions.** `docs/` records why something is the way it
is, constraints that span components, and traps the source cannot show. When a decision changes,
rewrite the text; do not append. *Evidence:* reported (T3 Code, OpenAI).

**24. Specs and decisions are committed. Step-by-step implementation plans are not, unless the
client needs an audit trail.** The merged PR is the record of how. *Evidence:* judgement. T3 Code
commits no plans; our Lakehouse commits all of them. Both work. Choose per project and write the
choice in AGENTS.md.
