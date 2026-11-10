# RantAI engineering guidelines

Documents (`docs/`), a project template (`template/`) and a model bench (`bench/`). Engineers copy
from here into product repositories, so a wrong sentence or a broken script here spreads.

## Commands

| What | Command |
|---|---|
| Everything, before any handoff | `scripts/selftest.sh` (about two minutes) |
| Install the template into a project | `scripts/new-project.sh /path/to/project` (new) · `scripts/adopt.sh /path/to/repo` (existing code) |
| Set up one bench run, then grade it | `bench/harness/setup-run.sh <task> <label>` · `bench/harness/grade.sh <task> <label>` |

## Where things live

- `docs/` — rules and reasons. `sources.md` is the only place a source is described.
- `install.sh` — the one entry point: `new`, `adopt`, `skill`. The public one-liner runs this file.
- `skill/rantai-guidelines/` — the skill installed on a person's machine, so an agent in any
  project can do the whole setup. `llms.txt` points agents at it.
- `template/` — copied verbatim into projects. `template/AGENTS.md` keeps its `TODO(fill)` lines.
- `stacks/` — per-language notes and config snippets.
- `bench/fixture-*`, `bench/tasks/` — fixtures, briefs, hidden tests, reference solutions.
- `bench/results/` — one dated file per bench run. Never edit an old one; add a new one.

## Working agreements

1. **Every claim has a source or a tag.** A number comes from `docs/sources.md` or from a results
   file. A rule with no evidence is tagged "judgement". Do not write "studies show".
2. **Check a quote against the page** before it goes in `sources.md`. If you could not, say so there.
3. **A template change is proven by `scripts/selftest.sh`**, not by reading it.
4. **A new bench task ships with a reference solution**: the unsolved fixture fails the hidden tests
   and the reference passes all of them. Add both checks to `selftest.sh`.
5. **Model names go in `docs/orchestration.md` and results files only.** Everywhere else, name the
   role (lead, worker, reviewer).
6. **No client names, client code or real hostnames** anywhere in this repository.
7. **Plain language.** Short sentences, no slogans. If a sentence would fit any guideline document,
   delete it.

## If you are an agent in some other repository

You were probably asked to "use the RantAI guidelines". Do not work in this repository. Follow
`skill/rantai-guidelines/SKILL.md`; it installs the template into the project you came from.

## Traps

- `bench/fixture-ts/src/features/pricing/index.ts` contains the token `__FENCE_COMMENT__`.
  `setup-run.sh` replaces it. The fixture does not type-check until that has run; this is intended.
- `bench/fixture-ts` has a deliberate rounding bug in `price-cart.ts` and deliberate noise comments.
  Do not fix them.
- A bench run spends worker quota. About fifty worker sessions in one day used up a monthly
  OpenCode Go plan. Ask the owner before running more than a handful, and never switch on paid
  extra usage yourself.
- `template/scripts/tracker-lark.sh` talks to a real Lark base. Test it with reads and with
  previews. Never pass `--yes` while testing, and never put a base token, a person's name or a
  ticket's text in this repository.
- Run directories under `/tmp/rantai-bench` are scratch. Results worth keeping are copied into
  `bench/results/`.
