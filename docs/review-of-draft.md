# Review of the draft guide and the draft orchestration plan

The draft guide ("State-of-the-Art Coding & Architecture in the AI Era") was checked claim by
claim against primary sources, against T3 Code's actual repository (commit `20c3dd3`, 10 November
2026), and against our own runs. Verdicts: **keep**, **change**, **drop**.

The short version: the draft's instincts about enforcement and independent review are right. Its
specific numbers and several of its named practices are not what the sources it cites actually do.

## 1. Architecture and repository structure

| Draft claim | Verdict | What we found |
|---|---|---|
| Layering by technical role makes agents thrash and causes silent regressions | **Change** | No study compares slices with layers for agents. T3 Code's server is domain folders plus packages, not feature slices. What two independent teams report working is a dependency direction enforced by a script. Rule: group by what changes together, enforce one direction. |
| `/packages/contracts` as the single source of truth for schemas | **Keep** | T3 Code does this (`packages/contracts`, no internal dependencies). Our Lakehouse does this. |
| Apps are stateless services that project server-side domain events | **Drop** | This describes T3 Code's own event-sourced design. It is not a general rule. |
| Each vertical slice holds its schema, logic, transport, UI and tests in one folder | **Change** | Colocated tests: yes. But schema-in-the-slice contradicts contract-first, and a Rust API with a Next.js console cannot share a folder. Use slices inside one runtime. |
| Interface, DI layer and implementation in one module | **Keep, reworded** | It is T3 Code's convention for Effect services: "One module per service". The general point stands: do not split one service over several files without a reason. |
| Vendor reference libraries in `.repos/` | **Keep, narrowly** | Verified: T3 Code vendors `effect` and `alchemy-effect`. Do it for a library models get wrong. Do not vendor everything; T3 Code's checkout is 31,901 files. |

## 2. Separation of concerns

| Draft claim | Verdict | What we found |
|---|---|---|
| Components communicate only through runtime-validated schemas | **Change** | Validate at process and trust boundaries. Inside one process the type checker is the validator. |
| Rule of three before DRY; tolerate duplication | **Keep, with a counterweight** | Agents already duplicate too much: copy-pasted lines 9.4% → 15.7% and refactored lines 21% → 3.8% over about four years to 2026. Add a dead-code tool to the gate and "search before you write" to AGENTS.md. |
| Errors as values, via Effect-TS or `Result` | **Keep the principle, drop Effect as a default** | No evidence either way on typed errors and agents. Effect is a large framework that models get wrong often enough that T3 Code vendors its source. A five-line `Result` type does the job. |
| Parse, don't validate; branded ids | **Keep** | Judgement call; cheap to do. |

## 3. Code style and tooling

| Draft claim | Verdict | What we found |
|---|---|---|
| Fast native linters and checkers | **Keep, and go further** | One gate script, a changed-only mode, and error messages written as fix instructions. |
| Files of 150–300 lines; over 500 degrades attention and causes "existing code" truncation | **Change** | No evidence for a cap that tight, and the truncation habit came from tools that rewrote whole files. But no cap at all is worse: T3 Code has no rule and has a file of 14,720 lines, and we have had files of 30,000. We enforce a ceiling by script, 600 lines and 1,000 for Rust, and freeze files already over it so they can only shrink. |
| Explicit over implicit; no decorators, singletons, monkey-patching | **Keep** | Judgement call. |

## 4. Context and documentation

| Draft claim | Verdict | What we found |
|---|---|---|
| Root `AGENTS.md` under 200–300 lines, about 1,500 tokens | **Change the number** | The two limits contradict each other. T3 Code's 212-line file is 24.6 KB, roughly 6,000 tokens. Use 200 lines, which is Claude Code's documented target. |
| Never document what the agent can infer | **Keep** | Supported: generated context files did not improve success and cost over 20% more. |
| Path-scoped rules in `.claude/rules/*.md` | **Change** | The feature is real (`paths:` frontmatter). It is Claude-only. OpenCode and Antigravity workers never see those files. Use a nested `AGENTS.md`. |
| Reusable workflows in `.agents/skills/` | **Keep, with two additions** | Claude Code reads only `.claude/skills`, so symlink it. And skills are not reliably invoked (never, in 56% of one evaluation), so name the skill in AGENTS.md at the point of need. |
| `@module` header on every non-trivial file | **Drop** | 13 of T3 Code's 4,078 source files have one. Its lint caps any comment at four lines. Headers describe, and descriptions rot. |
| `// INVARIANT:` and `// AI-NOTE:` markers | **Drop the markers, keep the practice** | T3 Code has zero of each. The marker is not what helps. In our runs a plain one-line reason was enough. A reason is for every reader. |
| No "what" comments | **Keep** | T3 Code enforces it by lint. |

## 5. Harness and multi-agent execution

| Draft claim | Verdict | What we found |
|---|---|---|
| Guidance in `CLAUDE.md`, hard limits in deterministic hooks and CI | **Keep the split, move the hooks** | Claude Code hooks do not fire for an OpenCode or Antigravity worker. Hard limits belong where every harness passes: git hook, the lead's gate scripts, CI. |
| Planner writes an immutable `feature_list.json` | **Drop** | That is from Anthropic's harness for building a whole application from one prompt across many sessions. Our backlog and one spec per feature already do this job. Keep the idea underneath: the worker cannot edit the definition of done. |
| Generator works on clean-context slices and tests before committing | **Keep** | |
| Independent evaluator drives the live app with Playwright | **Keep for UI work, with Anthropic's own warning** | Their full harness cost $200 against $9 for a solo run, and they wrote that the evaluator is "worth the cost when the task sits beyond what the current model does reliably solo". For a backend slice, planner-written acceptance tests plus a fresh reviewer are the evaluator. |
| "Skeptical memory" | **Keep the practice, fix the source** | The phrase is from third-party analyses of leaked Claude Code source, not from Anthropic. |

## The orchestration plan

Draft: T3 Code orchestrates, Opus plans and reviews, and DeepSeek V4.1 Flash, MiniMax M3.1 Flash,
GLM-5.3 and Gemini 3.8 Flash write the code.

**What the draft gets right, and we kept:** a strong model plans and a cheaper one builds; the
author does not review its own work; the plan carries acceptance checks; the handoff carries
evidence; the reviewer re-runs the check instead of trusting "green". The Lakehouse AGENTS.md
already says most of this better than the public advice does.

**What we changed, with the reason for each:**

1. **Four interchangeable workers became three with roles.** No model was better at one kind of
   task than another, so a routing table by task type would be decoration. What differed was
   reliability, reporting and speed. MiniMax is the default, DeepSeek the fast pool, GLM-5.3 the
   second attempt. Gemini through Antigravity is out. Claude Sonnet and Haiku ran as controls only;
   RantAI does not use them as workers because of cost.

2. **The four are not equally cheap, and price per token is not what you pay.** List price per
   million tokens in and out: MiniMax M3.1 Flash $0.15 / $0.60; DeepSeek V4.1 Flash $0.30 / $1.20
   at peak; Gemini 3.8 Flash $0.75 / $3.75, doubling in January 2027; GLM-5.3 $1.40 / $4.40, nine
   times MiniMax, and it is not a flash model. On a flat-rate plan the real costs are quota and the
   lead's waiting time. The MiniMax coding plan ran out on our first task, and all three chosen
   workers now share one OpenCode Go subscription, so a second route has to be ready.

3. **Planner and reviewer in one thread share blind spots.** Our own plan had an ambiguous
   sentence. Our own acceptance tests missed it. Fresh reviewers found it. The reviewer is a new
   task that sees the plan and the diff and nothing else.

4. **"Opus never writes code" sends every task through the most expensive path.** Anthropic's
   measurements show delegation winning only for routine work with a long cost tail and for work
   larger than one context window. Route first. The rule that matters is that the author's context
   never reviews the author's work.

5. **A review is not a gate.** Scope, protected paths, removed tests and the check are decided by
   scripts before anyone reads the diff.

6. **Acceptance tests must not come from the worker.** The one worker that misread the plan wrote
   19 passing tests around its misreading and reported no deviations.

7. **The enforcement was shaped for Claude Code.** Hooks and `.claude/rules` do nothing for the
   three workers that run in OpenCode and Antigravity.

8. **Some routes are a business risk.** Reselling proxies for subscription logins break the
   providers' terms and put client code in a third party's hands. See the table in
   [orchestration.md](orchestration.md).

9. **Wall time was ignored.** Gemini through Antigravity took 3.5 to 9 minutes for slices DeepSeek
   finished in 1 to 2.5. With a lead waiting on every handoff, the slow worker costs more than its
   token price suggests.

10. **A script decides which changes need a person.** Nobody reads diffs line by line. A green,
    reviewed pull request in the auto lane merges. Auth, money, tenancy, migrations, deletes,
    protected paths, new dependencies and suppressions go to the owner, who approves the evidence.

11. **Model names expire.** The draft named four models that did not exist a few months ago. The
    plan now names roles, and `bench/` re-qualifies the models that fill them.
