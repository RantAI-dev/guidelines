# Orchestration

How RantAI runs a feature through T3 Code with one lead model and cheaper workers. This is the
design we recommend after testing the draft plan; what we changed and why is in
[review-of-draft.md](review-of-draft.md), and the runs behind the numbers are in
[bench/results](../bench/results/2026-11-10.md).

## The shape

The owner works through one long-lived desk thread that is connected to the tracker. It starts a
feature lead for each feature; the diagram below is what happens inside one feature. The desk is
described in [desk-thread.md](desk-thread.md).

```
owner (person)      scope, protected paths, merge of risky changes
   │
lead (Opus 5.5)     route → plan → contracts + acceptance tests → brief
   │                                                    ▲
   ├── worker A (own worktree) ── handoff ──┐           │ findings
   ├── worker B (own worktree) ── handoff ──┤           │
   │                                        ▼           │
   │                         gate: guard-diff.sh + check.sh   (scripts, not opinions)
   │                                        │
   └── reviewer (fresh context, sees plan + diff only) ──┘
   │
lead integrates, one branch at a time → pull request → CI → merge
```

Three things carry the weight, in this order:

1. **The plan.** In our runs, six different models all scored 100% on a feature slice when the plan
   stated every behaviour as a checkable sentence. Worker choice changed the time taken, not the
   result.
2. **Scripts that decide.** Scope, protected paths, removed tests and the check itself are decided
   by `guard-diff.sh` and `check.sh`, never by a model's reading of a diff.
3. **Independence.** The reviewer has never seen the lead's reasoning, and the acceptance tests were
   not written by the worker.

## Who does what

| Role | Model | Why |
|---|---|---|
| Owner | a person | Signs scope and numbers. Reads the plan and the evidence, not the diff. Approves the owner lane: whatever `scripts/merge-lane.sh` flags. See [no-read-workflow.md](no-read-workflow.md). |
| Desk | Claude Opus 5.5, medium effort, one long-lived thread | The only thread the owner talks to. Reads a digest of the tracker, routes tickets, starts children, merges by lane, updates tickets. Holds no plans, code or diffs. |
| Lead | Claude Opus 5.5 in a child of the desk, one per feature, medium effort; high only to plan risky work | Plans, writes contracts and acceptance cases, briefs, runs the gate scripts, judges disputes, integrates. Its budget is the constraint: see [lead-budget.md](lead-budget.md). |
| Scout | DeepSeek V4.1 Flash, read-only | Answers "where is X done" in 40 lines with anchors, so the lead does not read the codebase. |
| Worker, default | MiniMax M3.1 Flash through OpenCode Go | The only one of the four with no mistake in our runs. It passed every hidden test, kept the unexplained special case and asked about it, and wrote the most thorough handoffs. About 2 to 3.5 minutes per slice. |
| Worker, fast pool | DeepSeek V4.1 Flash through OpenCode Go | About twice as fast as MiniMax, so use it when several slices run in parallel. It misread one plan sentence on the Rust task and deleted the unexplained special case (and said so). Planner-written acceptance tests catch both, so never run it without them. |
| Worker, second attempt | GLM-5.3 through OpenCode Go | For a slice the default failed once. It has the highest independent Terminal-Bench 4.0 score of the four (41.9%) and passed every hidden test here. It is slow (2.5 to 7.5 minutes) and it also deleted the special case (and said so). |
| Reviewer, first pass | A pool model that did not write the code: DeepSeek, or GLM-5.3 when DeepSeek is the author | With the review brief, each found all four planted bugs, the same as Opus. Their findings go to the author to reproduce and fix. They over-call BLOCKER on ambiguous cases, so the lead judges severity. |
| Reviewer, risky paths | Claude Opus 5.5 in a new task, never the planning thread | In addition to the first pass, for auth, money, tenancy, migrations and deletes. It was the best calibrated on severity. |

Claude Sonnet 5.5 and Haiku 5.5 appear in the results as controls only. RantAI does not use them
as workers because of cost, so the pool is chosen from the four draft models.

**Not in the pool: Gemini 3.8 Flash through Antigravity.** It passed every hidden test, but it was
the slowest by a wide margin (up to 9 minutes for work DeepSeek did in 1 to 2), and its notes for
the reviewer were "none" in all four handoffs we read. It did report the plan conflict when a rule
told it to. But in the run where it deleted a public export and a special case without being asked
to, it wrote "none" under both deviations and notes. A worker that does not report costs the lead
its cheapest signal. Antigravity's terms also allow Google to use interactions to improve its
models unless you opt out, and the list price doubles on 2027-01-01. Keep it only as a spare route
for the day OpenCode Go is down.

The four were never interchangeable, and none was better at one kind of task than another. What
differed was reliability, reporting and speed. So the pool is three models with roles, not a
routing table by task type.

**One subscription is one point of failure.** All three workers run on the same OpenCode Go plan.
A quota or outage there stops every worker at once. Keep a second route configured and tested.
On this installation OpenCode's pay-as-you-go console offers DeepSeek V4.1 Flash and GLM-5.3 as
paid models and MiniMax M3.1 Flash only as a free variant. Read the free variant's data terms
before client code goes through it; free tiers change without notice.

## Route first

Anthropic measured this directly: an orchestrator with cheaper subagents beat a single model in
only two situations, routine work with a long cost tail and work larger than one context window.
For a dependent chain, one model at lower effort won every time. Their advice: "Tune one model
before you add a second."

| The work is | Do this |
|---|---|
| One dependent chain: debugging an unknown cause, a migration, a change under about 50 lines | The lead does it in its own thread, at the lowest effort that works. A fresh reviewer still reviews it. |
| One slice that can be specified completely | One worker. |
| Several slices that touch different files | Contracts first, then one worker per slice, four at most. |
| Not yet specifiable | Read more, spike it, or ask the owner. |

"Opus never writes product code" is the wrong rule. The rule that protects you is **the author's
context never reviews the author's work**. When the lead writes the code, a fresh reviewer and the
scripts provide the independence.

## The loop

The lead's step-by-step version is the skill at
[template/.agents/skills/orchestrate/SKILL.md](../template/.agents/skills/orchestrate/SKILL.md).
In short:

1. **Route.** Decide whether to delegate at all.
2. **Plan.** Every behaviour is one sentence a test can check: exact error shapes, the order of
   checks, which side of a boundary is included, an example wherever a number is formatted.
3. **Write down "done" first.** Commit contract changes and acceptance tests before any worker
   starts, and add them to `.agents/protected-paths`.
4. **Brief.** The worker gets the brief and nothing else. Use the template: repository, task,
   scope, done criteria, the fixed handoff shape.
5. **Gate.** Run `scripts/guard-diff.sh <base> --scope '<regex>'` and `scripts/check.sh` in the
   worker's checkout. A failure goes straight back. Compare the result with the handoff's CHECK line.
6. **Review.** A new task with the review brief: the plan, the commit range, none of the lead's
   reasoning. A pool model that did not write the code goes first, and its findings go to the
   author. Two rounds at most, then the lead takes over or the owner is asked.
7. **Integrate.** One writer. Merge worker branches one at a time and run the check after each.
8. **Close.** Fold what the handoff notes and the review revealed back into the plan or the rules.

Read the handoff's `NOTES FOR REVIEWER`. In our runs the notes were where the real information
was: several workers independently flagged an ambiguity in our own plan, and five of the six
workers that met the unexplained special case wrote about it, including two of the three that
deleted it. An empty notes section on a non-trivial change is itself a reason to read the diff.

## What the runs showed

Six models, seven task variants, one run each, plus 10 review runs. Small numbers: read them as
"what can happen", not as rates.

| Finding | Detail |
|---|---|
| A precise plan flattens the differences between workers. | Feature slice, 21 hidden tests: every model 21/21. Bug fix: every model fixed it and added the regression test. |
| Workers follow a written conflict rule. | Plan and contract test disagreed on purpose. All six followed the contract test, left it untouched and reported the deviation. |
| A worker's own tests cannot catch its own misreading. | Rust task: DeepSeek misread one sentence, wrote 19 passing tests around the misreading, reported no deviations, and failed 2 of 13 independent tests. |
| A one-line reason protects odd-looking code. | With a why-comment, 6 of 6 kept a strange special case during a tidy-up. Without it, 3 of 6 deleted it. Two said so in their notes. One also deleted a public export and reported "none" under deviations and notes. |
| A fresh reviewer that walks the plan finds planted bugs, whatever the model. | Four planted plan violations that passed the author's 19 tests: all six reviewer models found all four, with no false findings. |
| Review finds what tests do not. | On the "clean" control, three of four reviewers found a real ordering defect that our 21 hidden tests and our own reference solution had missed. |
| Reviewers differ in judgement more than in detection. | That defect came from an ambiguous plan sentence. Opus called it SHOULD-FIX, two cheaper models called it BLOCKER, Sonnet noticed it and chose not to report it. |
| Speed differs by about four times among the four. | DeepSeek took about 1 to 2.5 minutes per task, MiniMax 2 to 3.5, GLM 2.5 to 7.5, Gemini 3.5 to 9. The two Claude controls took 1 to 2. |
| Subscriptions fail at bad moments. | The MiniMax coding plan hit its usage limit on the first task. Every worker needs a named fallback. |

What these runs cannot tell you: how the cheap models do on long tasks in a large codebase. Public
benchmarks say the gap there is large. On Terminal-Bench 4.0, measured independently, Sonnet 5.5
scores 63.6% and the four draft workers score between 19.7% and 41.9%. That gap is the reason for
the routing rule: the workers get slices small and specified enough that the gap does not show,
and work that cannot be cut that way stays with the lead.

## Data and accounts

Decide the route before the model. For client code, a route must have written terms that say the
provider does not train on the data and does not keep it.

| Route | Terms, as published in November 2026 | Client code |
|---|---|---|
| Claude through the Anthropic API or a Team or Enterprise plan | Not used for training; deleted within 30 days by default | Yes |
| Claude through a personal Pro or Max plan | Consumer terms apply, and they differ from the commercial ones | Only after checking the account's model-training setting |
| DeepSeek, MiniMax, GLM through OpenCode Go | "Not used" for training, 0 days retention. DeepSeek's agreement is renewed monthly and needs the Global region setting. | Yes, and check the DeepSeek date each month |
| DeepSeek, GLM through OpenCode's pay-as-you-go console | Zero retention and no training, with named exceptions for some free models | Yes for the paid models; check each free one |
| DeepSeek direct API | Stored in China; used to improve the service unless you opt out | No |
| MiniMax direct coding plan | Content may be used to improve features | No |
| Gemini through an Antigravity sign-in | Interactions used to improve models unless opted out | Only after opting out |
| Any proxy that resells subscription logins | Google's terms call third-party access to Antigravity "a breach of this Agreement" and there are reports of suspended accounts. Anthropic's terms do not permit routing requests through subscription credentials. Client code also passes through the proxy operator. | No |

The last row matters. Check the default model in `~/.config/opencode/opencode.jsonc` on every
machine that touches client code. If it is a proxy route, change it to a first-party route or to
OpenCode Go before the next session.

## When to re-run the bench

The model names in this file will be out of date within months. The roles will not. Re-run
`bench/` and update the table when:

- a model in the table gets a new version, or a cheaper model appears;
- you change the brief template, the review brief or the working agreements in AGENTS.md;
- a worker makes the same kind of mistake twice in real work. Add a task that reproduces it first.

Add tasks taken from your own merged pull requests: check out the parent commit, give the worker the
ticket text, and use the tests from the real fix as the hidden tests. Five of those will tell you
more about your codebase than any public leaderboard.

## When things go wrong

| What happened | What to do |
|---|---|
| A worker's route returns a quota or rate error | Start the same brief on the same model through the second route. Do not wait. If the whole subscription is out, as happened to us twice in one day, the owner decides whether to pay for extra usage. An agent never turns that on. |
| A worker is still running after 15 minutes on a one-slice brief | Cancel it and start the brief on DeepSeek. The longest run we saw on a small slice was 9 minutes. |
| The gate fails twice on the same slice | Check the plan first: a second failure is usually a plan problem. Then give the slice to GLM-5.3 once, with the failing output in the brief. If that fails, the lead does it. |
| The handoff says green and the gate says red | Treat every claim in that handoff as unverified and read the diff line by line. |
| Reviewer and worker disagree after two rounds | The lead decides and writes the reason in the pull request. |
| A worker changed a protected path | Blocked by `guard-diff.sh`. Only the owner unblocks it. |
| A bug reached production | Write the failing test first, then fix. Add one line to the tracker: which of the six safeguards in no-read-workflow.md should have caught it. |
