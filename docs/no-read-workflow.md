# Shipping code that nobody reads

Our engineers direct agents and do not read diffs line by line. This page says what has to be true
for that to be safe, and which file in the template makes each thing true.

## What others who work this way rely on

We checked what we could.

- **T3 Code**, from its repository. People steer and agents write. Three review bots run on every
  pull request, with written rules for what a bot may approve on its own: a change to product
  defaults, or one that switches off a lint or type check, is not auto-approvable. Proof is
  required by kind of change: a failing test first for logic bugs, before and after captures for
  visual ones, a runtime transcript for server-only fixes. "A checkbox or 'tests pass' alone does
  not show that the change works."
- **Bun's rewrite in Rust**, from public coverage. About a million lines written by agents and
  merged in May 2026. What stood in for reading was the existing test suite as the gate and
  adversarial review by agents. Regressions still appeared after the merge and were fixed.
- **OpenAI's Codex team**, from their write-up. "We've pushed almost all review effort towards
  being handled agent-to-agent", with rules encoded as lints and a background clean-up agent.

We did not find a statement from any of them that understanding can be skipped. What they skip is
the line-by-line read. What they do not skip is the plan, the proof, and a gate that fails loudly.

## Six things that must be true

**1. People read intent and evidence.** The engineer reads the plan's behaviour list before the
build and the pull request's evidence after it: the check output, the lane, the proof for that
kind of change. They look at the running product, not at the code.
*In the template:* `plan.md`, `.github/pull_request_template.md`.

**2. "Done" is written down where an agent cannot quietly change it.** Acceptance tests come from
the planner before the build. Invariants that must never break, such as tenant isolation and
permission checks, are tests too. All of them are protected paths.
*In the template:* `.agents/protected-paths`, `scripts/guard-diff.sh`.

**3. Something independent reads the diff, even though no person does.** A fresh-context reviewer
from the worker pool walks the plan sentence by sentence. In our bench every model tested found
every planted bug this way. Its findings go to the author to reproduce and fix.
*In the template:* `review-brief.md`.

**4. A script decides which changes still need a person.** Most changes go through on green
checks. A change that touches auth, money, tenancy, a migration, a delete, a protected path, a
dependency or a suppression goes to the owner, who approves the evidence and not the diff.
*In the template:* `scripts/merge-lane.sh`, `.agents/risky-paths`, the lane step in CI.

**5. Production is the last reviewer, so it must be cheap to be wrong.** Every pull request says
how to turn the change off. Risky changes ship behind a flag or to a small share of traffic first.
An error in production becomes a failing test before it becomes a fix.
*In the template:* the "If it goes wrong" section of the pull request template.

**6. Something cleans up on a schedule.** When nobody reads the code, nobody notices it rotting.
A weekly worker job pays down one ratchet metric, removes dead code and fixes stale documents.
*In the template:* the `sweep` skill, `scripts/ratchet.sh`. Schedule it in T3 Code.

## The two lanes

| | Auto lane | Owner lane |
|---|---|---|
| Which changes | Everything `scripts/merge-lane.sh` does not flag | Risky paths, protected paths, removed or skipped tests, new suppressions, new dependencies, a possible secret, more than 600 changed lines |
| What merges it | Green check, green guard, clean first-pass review | The same, plus the `owner-approved` label |
| What the person reads | Nothing, unless they choose to | The plan, the evidence, the reasons the script printed |
| What the person does not need to read | The diff | The diff |

Fill in `.agents/risky-paths` for each repository on day one. An empty list means every change is
in the auto lane.

## What the engineer's job is now

- Say what should exist, precisely enough that a test can check it.
- Decide the cases: boundaries, tenancy, money, what must never happen.
- Use the product after each change. A person is still the best judge of whether it is right.
- Approve the owner lane by its evidence.
- When a mistake happens twice, change the harness: a lint rule, a test, a line in "Traps".

## Where this can still hurt

- **The plan is the only thing a person reads, so a wrong plan ships.** Our own bench plan had an
  ambiguous sentence. Tests missed it. Independent reviewers caught it.
- **Agents do not report everything.** One worker deleted a public export and wrote "none" under
  deviations. Pin the public surface with a test.
- **Tests that agents wrote can share the agent's misunderstanding.** That is why acceptance cases
  come from the planner, and from the old implementation in a port.
- **We have not measured defect rates under this workflow.** The claims above are about what each
  mechanism caught in small runs, not about how often production breaks. Track escapes: every
  production bug gets an incident with its root cause (see [tracker.md](tracker.md)).
