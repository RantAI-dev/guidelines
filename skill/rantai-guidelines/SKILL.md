---
name: rantai-guidelines
description: Set up a repository to follow the RantAI engineering guidelines, end to end - scaffold a new project, adopt the guidelines in an existing codebase, start a refactor towards them, or start porting code to another language. Use when the user says to use, apply, follow or set up the RantAI guidelines, to scaffold or bootstrap a project, to make a repository ready for agent workers, or to begin a refactor or a language migration under the guidelines.
---

# RantAI guidelines: set a repository up

You do the whole setup. The person should not have to copy or fill in anything by hand. They
decide three things at the end, and you ask for those in one message.

## 1. Get the guidelines

```bash
G="${RANTAI_GUIDELINES_HOME:-$HOME/.rantai/guidelines}"
[ -d "$G/.git" ] && git -C "$G" pull --quiet --ff-only || git clone --quiet --depth 1 https://github.com/RantAI-dev/guidelines.git "$G"
```

Do not read its documents into your context. The steps here are enough. If you need the reason for
a rule, `$G/README.md` says which document has it.

## 2. Decide the situation from the repository

| You see | Situation | Run |
|---|---|---|
| No commits, or no source files | New project | `"$G/install.sh" new .` |
| Source code, but no `scripts/check.sh` | Existing project | `"$G/install.sh" adopt .` (it prints an audit first) |
| `scripts/check.sh` and `.agents/skills/` | Already installed | Nothing. Go to step 4. |

The installer never overwrites. It lists what it left alone. Merge those yourself: keep the
project's own `AGENTS.md` content and add the template's "Working agreements" and "Roles" sections
from `$G/template/AGENTS.md`; add the template's `.gitignore` lines.

## 3. Finish the setup, so the gate is real

Work on a branch named `chore/guidelines`. Change no product code in this step.

1. **`scripts/check.sh`.** In the CONFIGURE block keep only the parts (stacks) this repository has, and
   point each command at what it really uses (read `package.json` scripts, `Cargo.toml`,
   `pyproject.toml`). If the repository has no lint configuration, copy the snippet from
   `$G/stacks/<language>/`. Run it until it prints `check: PASS`. In an existing project, a rule
   that fails on old code becomes a ratchet line, not a mass fix: `scripts/audit.sh` prints the
   lines, paste them into `.agents/ratchet.tsv`, run `scripts/ratchet.sh --update`. Files already
   over the size limit are frozen the same way: `scripts/file-size.sh --update`.
2. **`AGENTS.md`.** Replace every `TODO(fill)` with facts you checked: the commands you just ran,
   the top-level areas and which way they depend on each other, the rules the gate enforces. Take
   the two-sentence description from the README. Write "none recorded yet" under Traps. Do not
   write a tour of the directory tree or anything an agent can find by reading. Under 200 lines.
3. **`.agents/protected-paths`.** Add what exists here: contract or acceptance tests, migrations
   already applied, lint and type-check configuration.
4. **`.agents/risky-paths`.** Propose lines for the directories that exist: auth, payments,
   tenancy, migrations, deploy. An empty file means no change ever needs a person.
5. **Error codes.** If the repository serves an API, add an `@emit <ts|rust|python> <path>` line to
   `.agents/error-codes.tsv` pointing at its contracts folder, run `scripts/error-codes.sh --write`,
   and copy the helper from `$G/stacks/<language>/`. New code follows `docs/conventions.md`. In an
   existing project, do not change what responses look like here; the `adopt-guidelines` skill
   records the differences for the owner.
6. **`CODEOWNERS`.** Replace `@TODO-owner`.
7. **Hooks.** Run `scripts/setup-worktree.sh`. Commit subjects are `type(scope): summary` from now on.
8. Commit. Do not push to the main branch. Open a pull request only if asked.

Then ask the owner, in one message, for the three decisions that are theirs: the risky-paths list,
the code owner, and whether the project keeps a `BACKLOG.md` and a Lark copy (small and one-person
projects skip both). Tell them to make `ci-required` the one required check on the main branch;
that is a repository setting you cannot change from here.

## 4. Carry on with what was asked

The project now has its own skills in `.agents/skills/`. Load the one that fits:

| The person wants | Load |
|---|---|
| The repository brought up to the guidelines, or refactored | `adopt-guidelines`, from its step 1 |
| Code moved to another language | `port-code` |
| The project run from this thread | `desk` |
| One feature planned, built and reviewed | `orchestrate` |
| Regular clean-up | `sweep` |

## 5. Report

Five lines: what was installed, the last line of `scripts/check.sh`, the audit's gap count before
and after, what was left alone, and the three decisions waiting for the owner.

## Never

Overwrite an existing file. Change product code during setup. Switch on paid usage. Write to Lark
or any tracker. Push to the main branch.
