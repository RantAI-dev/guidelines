# The board: BACKLOG.md, and Lark if the project needs it

Where the list of work lives, who may change what, and how the Lark base fits in. Lark is optional.

## Three sizes of project

| Project | Board | What you set up |
|---|---|---|
| Small, or one person | None. The owner tells the desk thread what to do, and the pull request is the record. | Nothing. |
| A product with a backlog | `BACKLOG.md` in the repository: one row per item with a stable ID, status and pull request. | The file, and a line in AGENTS.md naming it. |
| A product that people outside the repository follow | `BACKLOG.md`, mirrored to the Lark base. | The two lines in `.env` below. |

Do not add a tracker to make a small project look managed. Add one when a second person needs to
see the state of the work without asking.

## The repository is the master of everything

Decided by the owner on 10 November 2026, and the same rule the Lakehouse project already follows.
The repository holds the item: its ID, text, acceptance criteria, status, pull request and dates.
The Lark base is a copy. It adds only what a repository should not hold, which is the people:
owner, acceptor, assignee.

So every change goes repository first. The pull request that does the work also changes the item's
row in `BACKLOG.md`. After the merge, the desk copies the status and the pull request to the base.
Nothing is changed only in the base.

The scripts enforce this, so it does not depend on anyone remembering:

- `scripts/backlog.sh` reads the backlog from the main branch, one row at a time.
- `scripts/tracker-lark.sh` refuses to write a status to Lark unless the backlog on the main
  branch already shows that status for that item. It also refuses a row that has no Backlog ID,
  because that item is not in the repository yet.

**What follows from the rule.** A status reaches Lark at the merge, not before. While work is under
way, Lark still shows the item's last merged status, and the open pull request is the sign that
someone is on it. If people need to see "In Progress" in Lark sooner, the way to do it under this
rule is a small pull request that changes only the backlog row.

## How well this holds up, and where it strains

We compared the Lakehouse backlog on its main branch with the Lark base on 10 November 2026.

- **The mirror holds.** 303 of the base's 304 backlog IDs are in the repository. Of the 114
  statuses our simple parser could read, 109 matched. The discipline works.
- **The file is large.** 753 lines, about 38,000 tokens. An agent that reads it whole pays that
  every time. Read one row by its ID, never the file:
  `git show origin/main:docs/core/BACKLOG.md | grep -m1 '^| *`\?API-7'`
- **A branch carries an old board.** A checkout on this machine from four weeks earlier held 162
  items where main holds 322, and most of its statuses were out of date. Read the board from
  `origin/main`, as in the line above, not from the branch you are working on.
- **It is a busy file.** 344 of the last 3,512 commits on main touched it. Rows next to each other
  that change in two pull requests at once will conflict.
- **Work in progress is invisible on main.** "In Progress" and "Blocked" written on a branch are
  not on main until the merge, which is when they stop being true.

### What we do about the strain

- Agents read one row by ID with `scripts/backlog.sh get <ID>`, never the file.
- The script reads the main branch, so a branch's old copy cannot mislead anyone.
- A pull request changes only its own item's row. When two pull requests collide on neighbouring
  rows, the second rebases; nobody edits another item's row to make a merge easier.

## How the Lark base maps

Read from our base on 10 November 2026. The desk uses three of its tables.

| Table | Fields the desk reads | Fields the desk writes | Never the desk's |
|---|---|---|---|
| Tasks | Backlog ID, Status, PR, to compare with the repository | Status, PR, Notes, Blocked Reason, Completed, copied from the repository | Assignee, Due |
| Features | Backlog ID, Status | Status, Evidence, Started, Shipped, copied from the repository | Owner, Acceptor, Verification, Release, QA Cases |
| Incidents | everything, when asked | nothing | all of it: a person files an incident |

Status values, in the base's own words:

| | The desk sets | A person sets |
|---|---|---|
| Task | In Progress, In Review, Blocked, Done | Todo (by creating it), QA Review, Cancelled |
| Feature | Building, In Acceptance | Idea, Planned, Dev Complete, Fixing, Released, Killed |

`scripts/tracker-lark.sh` enforces this table: it refuses any other status, it refuses a status the
repository does not show, and it has no command that writes a people field.

Two things in the base that the desk has to cope with:

- **Across all products, about four in ten tasks have no Backlog ID.** They were created in Lark
  directly, so the repository does not know them. `scripts/tracker-lark.sh ready` lists them. To
  work on one, a pull request first adds it to `BACKLOG.md` with a new ID, and a person puts that
  ID on the Lark row. Until then the desk does not touch it.
- **The base holds every product.** `LARK_PRODUCT` or `LARK_PROJECT` scopes every read and write to
  this repository's rows. Backlog IDs repeat across products, so the script stops if an ID matches
  more than one row.

## Setting it up, when you want it

```bash
# 1. once per machine
lark-cli auth status          # log in if it says so

# 2. once per project, in .env (never committed)
LARK_BASE_TOKEN=<the base's token, from its URL>
LARK_PRODUCT=<this repository's name in the Products table>

# 3. check it reads
scripts/tracker-lark.sh ready
```

Then add one line to AGENTS.md under "Where code lives": `Board: BACKLOG.md, mirrored to the Lark
base (scripts/tracker-lark.sh).`

## What the scripts do

| Command | What happens |
|---|---|
| `scripts/backlog.sh ready` | Prints up to 30 Todo rows from the backlog on the main branch. This is the desk's list. |
| `scripts/backlog.sh get API-7` | Prints that item's row. |
| `scripts/tracker-lark.sh set API-7 --status Done --pr <link>` | Checks that the backlog on main shows Done for API-7, then prints what it would write to Lark, and stops. |
| the same with `--yes` | Writes it. |
| `scripts/tracker-lark.sh feature API-2 --status "In Acceptance" --evidence "<check line>"` | The same for a feature row. |
| `scripts/tracker-lark.sh get API-7` | Prints the Lark row, to compare with the repository. |
| `scripts/tracker-lark.sh ready` | Prints Todo tasks in Lark, to spot ones the repository does not have. |

Writes need `--yes` on purpose. The first time in a project the desk shows the owner the preview
and asks once.

## Incidents close the loop

The base's Incidents table already has what the no-read workflow needs: "Found In" (Review, QA,
Production) and "Root Cause" (Spec, Code, Test gap, Eval gap, Infra). When something escapes, a
person files the incident and picks the cause, and the fix follows from it:

| Root cause | What to change |
|---|---|
| Spec | The plan template or the acceptance criteria on the item |
| Test gap | Add the acceptance test, and protect it |
| Eval gap | Add a case to `bench/`, then change the brief or the review brief |
| Code | A lint rule or a boundary check, if it can happen again |
| Infra | The rollback line in the pull request template, or the deploy |

## Other trackers

For Jira or anything else there is no script yet. The desk starts a cheap child with
`digest-brief.md` to read the board, and writes status through that tracker's own tool. The rule
about the repository being the master is the same.

## What was and was not tested

Reads were run against our real base: `ready` and `get`, by Backlog ID and by record ID, scoped to
one product. Writes were run only as previews. Nothing was written to Lark while building this. The
repository-first check is covered by `scripts/selftest.sh`.
