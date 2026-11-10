# What agents read

Instruction files, skills, hooks and permissions, for a fleet that mixes Claude Code, OpenCode and
Antigravity under T3 Code. Sources are in [sources.md](sources.md).

## The mixed-fleet problem

Most advice about agent setup assumes one harness. We run three, and they read different files.

| | Claude Code | OpenCode | Antigravity |
|---|---|---|---|
| Root instructions | `CLAUDE.md`; `AGENTS.md` only when no `CLAUDE.md` exists | `AGENTS.md`; `CLAUDE.md` as fallback | `AGENTS.md` or `GEMINI.md` |
| Path-scoped rules | `.claude/rules/*.md` with `paths:` | none; nested `AGENTS.md` | `.agents/rules/*.md` |
| Skills | `.claude/skills/` only | `.agents/skills/`, `.claude/skills/`, `.opencode/skills/` | `.agents/skills/` |
| Hooks | `.claude/settings.json`, 33 events | plugin hooks (`execute.before`, `execute.after`) | none documented |

So anything written only in `.claude/` is invisible to the workers. Three consequences:

1. **`AGENTS.md` is the source of truth. `CLAUDE.md` is one line: `@AGENTS.md`.**
2. **Skills live in `.agents/skills/`, and `.claude/skills` is a symlink to it.** T3 Code's own
   repository does exactly this.
3. **Enforcement lives where every harness must pass:** the git pre-commit hook, the lead's gate
   (`scripts/check.sh` and `scripts/guard-diff.sh`) and CI. A Claude Code hook is a convenience for
   Claude sessions. It is not the enforcement layer.

## AGENTS.md

**Fill it with checked facts, not with a generated overview.** A study of four agents on 438
tasks found that generated context files did not improve success and raised cost by more than 20%.
Files written by developers helped a little (2.4 points, not statistically significant) and also
raised cost. The authors' advice: include only what is not already in the repository's
documentation. So an agent may fill the file in, and our setup skill does, but only with what it
verified: the commands it ran, the areas and their dependency direction, the rules the gate
enforces. It writes no tour of the code. The owner reads the result once; it is under 60 lines.

**Keep it under 200 lines.** Claude Code's documentation gives that number and says longer files
"reduce adherence". OpenAI runs a roughly 100-line file as a table of contents and keeps the detail
in `docs/`. T3 Code's is 212 lines. CI in the template fails above 200.

**What goes in, in this order:**

1. Two or three sentences on what the project is.
2. Commands: the gate, the fast gate, one test, run locally.
3. Where code lives and which way dependencies point.
4. The rules the gate enforces that surprise newcomers.
5. Working agreements: evidence not claims, never weaken a gate, report a plan conflict, stay in
   scope, failing test first, why-comments only.
6. Traps: what went wrong here. T3 Code opens with "the three ways to hurt yourself". This is the
   most valuable section, and the only one that should grow over time.

**What stays out:** style rules a formatter or linter enforces, a tour of the directory tree,
anything an agent can find by reading the code, and emphasis. Capital letters do not make a rule
stick; a script does.

**Split only when the root file is over budget.** Then put an `AGENTS.md` in the subdirectory, with
a one-line `CLAUDE.md` beside it. The nearest file wins in every harness that follows the standard.
Do not use `.claude/rules/` for anything a worker needs.

## Skills

A skill is a procedure an agent loads when it needs it: a `SKILL.md` with a name, a description
and steps, plus any files it refers to. Only the name and description are loaded up front.

Use a skill for a procedure with steps: running a migration, cutting a release, orchestrating a
feature. Do not use one for knowledge the agent must always have. In Vercel's evaluation the agent
never invoked the skill in 56% of cases, and a compressed docs index in AGENTS.md beat the skill
100% to 79%. So AGENTS.md names the skill at the point of need: "asked to plan or delegate: load
the `orchestrate` skill".

Keep `SKILL.md` under about 100 lines and put templates in sibling files. Write the description in
the third person and start with what it does and when to use it.

## Permissions

The same deny list goes in `.claude/settings.json` and `opencode.json`: force push, push to the
main branch, `--no-verify`, `reset --hard`, merging a pull request. The template ships both, and the
OpenCode file is verified to load in OpenCode 2.2.6.

Permissions stop accidents. They do not stop a determined agent, which can write a script that does
the forbidden thing. Branch protection on the server is what actually protects the main branch.

## Hooks

Use a Claude Code hook when you want a Claude session to get feedback earlier than the gate would
give it, for example a `Stop` hook that runs `scripts/check.sh --changed` and exits 2 on failure.
It is optional. It does nothing for an OpenCode or Antigravity worker, and a rule that matters must
not depend on which harness happened to run.

## Worktrees

Every worker gets its own worktree: `delegate_task` with `isolation: "worktree"`. `t3.json` runs
`scripts/setup-worktree.sh` for each new one, which installs with a frozen lockfile, links `.env`
from the main checkout and turns on the git hooks. The script runs with `"async": false`, so the
agent starts only after setup has finished and cannot race it.

We saw why this matters during our own runs: a child started in a shared checkout reported the
parent repository's untracked files as if they were its own.

## Memory

Notes an agent saved in an earlier session are hints. Before acting on a note that names a file,
function or flag, check that it still exists. Do not save what the repository already records.

The phrase "skeptical memory" comes from third-party write-ups of leaked Claude Code source, not
from Anthropic's documentation. The official statement is narrower and makes the same point: a note
that was wrong, or that drifted as the code changed, can be read and trusted in a later session.

## When you change this setup

AGENTS.md, a skill or a brief template is text that changes what models do. T3 Code keeps an
`evals/` directory for exactly that text and re-runs it on every change. Ours is `bench/`: re-run
it when you change the brief template, the working agreements or the worker model.
