# RantAI engineering guidelines

How we structure repositories, write code and run coding agents, so that a person or an agent can
change our software without breaking it. Three parts:

- **`docs/`** — the rules and the reasons, each tagged with how strong its evidence is.
- **`template/`** — the files every new project starts with. Copy them in with one command.
- **`bench/`** — a small test of worker models, briefs and reviewers, so that "which model" is
  answered by runs. The first results are in [bench/results/2026-11-10.md](bench/results/2026-11-10.md).

## Where do I start?

### The short way: let your agent do it

Once per machine:

```bash
curl -fsSL https://raw.githubusercontent.com/RantAI-dev/guidelines/main/install.sh | bash -s -- skill
```

That installs one skill for Claude Code, OpenCode and Antigravity. From then on, in any project,
tell your agent what you want. It works out the situation, installs the template, configures the
checks, fills in `AGENTS.md` from what it verified, and asks you only for the decisions that are
yours.

| You want | Say |
|---|---|
| A new project set up | "Use the RantAI guidelines here." |
| An existing project brought up to the guidelines | "Use the RantAI guidelines here, then refactor this repo to follow them." |
| Code moved to another language | "Use the RantAI guidelines here. We are porting <module> from <old> to <new> because <reason>." |

An agent without the skill can be pointed at this repository instead: "Follow
https://raw.githubusercontent.com/RantAI-dev/guidelines/main/llms.txt".

### By hand, in one line

| Situation | Command |
|---|---|
| New project | `curl -fsSL https://raw.githubusercontent.com/RantAI-dev/guidelines/main/install.sh \| bash -s -- new my-project` |
| Existing project, to refactor or to port | `curl -fsSL https://raw.githubusercontent.com/RantAI-dev/guidelines/main/install.sh \| bash -s -- adopt .` |

Both install the template without overwriting anything. `adopt` prints the gaps first. After
either one, the six things left to fill in are printed, starting with `AGENTS.md`; or hand that
part to your agent with the sentences above. From a clone of this repository the same commands are
`./install.sh new <dir>` and `./install.sh adopt <dir>`.

What happens after the install, and why:

- **Refactoring an existing project:** the `adopt-guidelines` skill gets the checks green on the
  code as it is, freezes today's violations so they can only go down, and refactors one area at a
  time. See [docs/changing-code.md](docs/changing-code.md).
- **Porting to another language:** the `port-code` skill builds a command that runs the old code on
  any input, ports one module at a time against it, and writes down every deliberate difference.
  See [docs/changing-code.md](docs/changing-code.md).

### Optional: connect the project to Lark

Skip this for a small or one-person project. When other people need to see the state of the work,
add two lines to `.env` and the desk copies each merged item's status from `BACKLOG.md` to the
Lark base. The repository stays the master of everything. How:
[docs/tracker.md](docs/tracker.md).

## What the template gives a project


| File | What it does |
|---|---|
| `AGENTS.md`, `CLAUDE.md` | One instruction file every harness reads. Its `TODO(fill)` lines are filled from checked facts, by you or by your agent. |
| `scripts/check.sh` | The one gate: `--staged` in the pre-commit hook, `--changed` while iterating, full in CI. |
| `scripts/guard-diff.sh` | What the lead runs on a worker's branch: scope, protected paths, removed or skipped tests, suppressions, secrets. |
| `.agents/protected-paths` | The files that define "done" and "allowed". A worker cannot change them. |
| `scripts/merge-lane.sh`, `.agents/risky-paths` | Decides which changes merge on green and which need a person's yes. |
| `.github/pull_request_template.md` | Intent, behaviour, evidence, rollback: what a person reads instead of the diff. |
| `.agents/skills/sweep/` | The weekly clean-up job for a codebase nobody reads day to day. |
| `scripts/backlog.sh` | Reads the backlog from the main branch one row at a time. The repository is the master of the list of work. |
| `scripts/tracker-lark.sh`, `.env.example` | Optional. Copies a status to the Lark base, and refuses anything the backlog on main does not already show. |
| `scripts/file-size.sh` | Fails a source file over 600 lines, or 1,000 for Rust. A file already over that is frozen: it may shrink, never grow. |
| `scripts/audit.sh` | Reports a repository's gaps against the guidelines, so no model has to read it to find out. |
| `scripts/ratchet.sh` | Freezes today's violation counts. They may fall and never rise. |
| `.agents/skills/desk/` | The runbook for the one thread the owner talks to: intake, route, start children, merge by lane, update the tracker. |
| `.agents/skills/orchestrate/` | The lead's runbook, with the plan, brief, review-brief and scout-brief templates. |
| `.agents/skills/adopt-guidelines/` | Step by step: audit, green gate, ratchet, characterization tests, one kind of change per slice. |
| `.agents/skills/port-code/` | Step by step: oracle, ledger, one module per slice, hidden parity cases, differences log, cutover. |
| `.claude/settings.json`, `opencode.json` | The same deny list for both harnesses. |
| `t3.json`, `scripts/setup-worktree.sh` | Every T3 Code worktree is installed and hooked before the agent starts. |
| `.github/workflows/ci.yml`, `CODEOWNERS` | The same gate in CI, plus the guard and a size limit on `AGENTS.md`. |

Stack notes and config snippets for TypeScript, Rust and Python are in [`stacks/`](stacks/).

## Read, in this order

1. [docs/desk-thread.md](docs/desk-thread.md) — running the whole project from one thread that is
   connected to the tracker.
2. [docs/orchestration.md](docs/orchestration.md) — who plans, who builds, who reviews, on which
   model and route, and what to do when it goes wrong.
3. [docs/no-read-workflow.md](docs/no-read-workflow.md) — how we ship code nobody reads line by
   line: what the person reads instead, and which changes still need them.
4. [docs/lead-budget.md](docs/lead-budget.md) — where the lead model's tokens go, and how to spend
   fewer of them.
5. [docs/changing-code.md](docs/changing-code.md) — bringing an existing repository up to the
   guidelines, and moving code to another language.
6. [docs/engineering.md](docs/engineering.md) — 23 rules for structure, the gate, tests and comments.
7. [docs/conventions.md](docs/conventions.md) — what is the same in every codebase: the error body,
   statuses, error codes, messages, field names, lists, logs, configuration, commit subjects. The
   rules themselves are [one page](template/docs/conventions.md) that every project gets.
8. [docs/agent-context.md](docs/agent-context.md) — what each harness reads, and where to put things
   so all of them see it.
9. [docs/review-of-draft.md](docs/review-of-draft.md) — the earlier draft guide and orchestration
   plan, checked claim by claim.
10. [docs/sources.md](docs/sources.md) — every source, its date and what kind of evidence it is.

## The short version

1. A rule that a script checks holds. A rule that is only written down does not. Put the effort
   into `check.sh`, lint messages that say how to fix the problem, and protected paths.
2. One `AGENTS.md`, written by hand, under 200 lines: commands, where code lives, the traps.
3. With three harnesses, anything inside `.claude/` is invisible to most workers. Enforce in git
   hooks, the lead's gate and CI.
4. Route before you delegate. One dependent chain is one model's job. Delegate slices you can
   specify completely.
5. The plan decides the outcome. With a precise plan, six different models all scored 21 of 21.
6. The planner writes the acceptance tests, before the build. A worker's tests share its misreading.
7. The reviewer is a fresh context that sees the plan and the diff, nothing else.
8. Scripts gate first, then the review. Never the other way round.
9. Three workers with roles: a default, a fast pool, a second attempt. Choose the route for its
   data terms first, and keep a second route ready.
10. Model names expire. Re-run the bench when a model, a brief or a rule changes.
11. The lead costs turns times context, not words. One feature per thread; scripts and scouts read.
12. Old code changes behind pinned behaviour: a ratchet for refactors, an oracle for ports.
13. Nobody reads the diff. People read the plan and the evidence; a script says when they must.
14. No file grows without limit. The gate fails a source file over 600 lines, or 1,000 for Rust.
15. Every codebase answers the same way. One error body, one table of statuses, error codes from
    one registry that a script checks, and one page of conventions copied into every project.

## Check this repository

```bash
scripts/selftest.sh
```

It installs the template into a scratch project and runs its gate, checks that the pre-commit hook
and the guard block what they should, and proves that every bench task fails unsolved and passes
with its reference solution. About two minutes. Needs `bun`, `cargo` with clippy, `jq` and `git`.

## Limits

- The bench has one run per cell and small tasks. It shows what can happen, not how often.
- Prices, terms and model versions are as published on 10 November 2026. Check them again before
  you rely on one.
- Rules tagged "judgement" in `docs/engineering.md` have no evidence behind them either way. They
  are our choice, and a project may choose differently if it writes the choice down.
