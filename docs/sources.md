# Sources

Everything the other documents cite, with its date and what kind of evidence it is. Fetched on
10 November 2026 unless noted. Quotes were checked against the page text where the tool allowed;
the ones that were not are marked.

## Read directly

| Source | What we took from it |
|---|---|
| T3 Code repository, `github.com/pingdotgg/t3code`, commit `20c3dd3` (10 Nov 2026), read from a local clone | `AGENTS.md` (212 lines), `CLAUDE.md` = `@AGENTS.md`, `.claude/skills` → `.agents/skills`, `.repos/` vendoring, the custom lint plugin and its messages, `no-low-value-comments` (four-line cap), file-size distribution, `check:changed`, `t3.json`, `docs/orchestration-v2/`, `evals/` |
| Our own repositories: RantAI Lakehouse `AGENTS.md`, rantai-kb `AGENTS.md` | The planner / developer split, the handoff and review loop, "rules learned the hard way", build-time discipline |
| Our bench, `bench/results/2026-11-10.md` | Everything tagged "bench" |

## Anthropic (vendor documentation and experience reports)

| Source | Date | Used for |
|---|---|---|
| Claude Code docs: memory, best practices, hooks, sub-agents, skills, agent teams, costs (`code.claude.com/docs/en/…`) | living | "target under 200 lines per CLAUDE.md file"; `.claude/rules` with `paths:`; AGENTS.md read natively only when no CLAUDE.md exists (v2.1.277+); hooks give "deterministic control"; subagents start with "a fresh, isolated context window" |
| "Optimizing for cost and intelligence" (`platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence`) | living, 2026 | "delegation came out ahead in only two situations"; Opus 5.5 with Sonnet 5.5 subagents "cost about a third less ... and scored about the same"; Haiku subagents cut cost 32% and pass rate about 4 points; "Tune one model before you add a second". Anthropic calls these internal and directional. |
| Pricing (`platform.claude.com/docs/en/about-claude/pricing`) | living | Haiku 5.5 $0.10 / $0.50 up to 100K-token prompts; Sonnet 5.5 $2 / $10; Opus 5.5 $4 / $20. Checked against the page text. |
| "Building effective agents" | Dec 2024 | Prefer the simplest thing that works |
| "How we built our multi-agent research system" | Jun 2025 | Multi-agent uses about 15× the tokens of chat; "most coding tasks involve fewer truly parallelizable tasks than research"; a brief needs "an objective, an output format, guidance on the tools and sources to use, and clear task boundaries" |
| "Effective context engineering for AI agents" | Sep 2025 | Context rot; "the smallest possible set of high-signal tokens" |
| Effective harnesses for long-running agents (`anthropic.com/research/effective-harnesses-for-long-running-agents`) | Nov 2025 | Initializer and coding agent; the JSON feature list; "It is unacceptable to remove or edit tests" |
| Harness design for long-running application development (`anthropic.com/research/harness-design-long-running-apps`) | Mar 2026 | Planner, generator, evaluator; "Out of the box, Claude is a poor QA agent"; full harness "over 20x more expensive"; the evaluator "is worth the cost when the task sits beyond what the current model does reliably solo"; "every component in a harness encodes an assumption about what the model can't do on its own" |
| Building a C compiler with parallel Claude agents (`anthropic.com/research/building-c-compiler`) | Feb 2026 | "the task verifier is nearly perfect, otherwise Claude will solve the wrong problem" |
| The components of agent memory (`anthropic.com/research/components-of-agent-memory`) | Nov 2026 | A wrong or drifted note "can be read, and trusted, by Claude in a later session" |

## Other vendors and teams (experience reports)

| Source | Date | Used for |
|---|---|---|
| OpenAI, "Harness engineering: leveraging Codex in an agent-first world" | Feb 2026 | AGENTS.md as "the table of contents" (about 100 lines); layering "enforced mechanically via custom linters"; "we write the error messages to inject remediation instructions into agent context"; cleanup day replaced by encoded rules. Read from an archive copy. |
| Vercel, "AGENTS.md outperforms skills in our agent evals" | Jan 2026 | Baseline 53%, skill 53%, skill with explicit instructions 79%, docs index in AGENTS.md 100%; "In 56% of eval cases, the skill was never invoked". Vendor-run, one framework. |
| Cognition, "Don't Build Multi-Agents" and its 2026 follow-up (`cognition.com/blog/dont-build-multi-agents`, `/blog/multi-agents-working`) | Jun 2025, Apr 2026 | Writes stay single-threaded; review works "best when the coding and review agents do not share any context beforehand". Quotes not checked against raw page text. |
| HumanLayer, "Writing a good CLAUDE.md" | Nov 2025 | "Never send an LLM to do a linter's job". Its instruction-count figures are the author's estimate. |
| AGENTS.md specification, `agents.md` | living | Nearest file wins; governed by the Agentic AI Foundation under the Linux Foundation |
| OpenCode docs (`opencode.ai/docs/…`): rules, agents, skills, plugins, permissions, Go | living | Which files OpenCode reads; plugin hooks; Go's per-model data terms |
| Antigravity docs and terms (`antigravity.google/…`) | living | Which files it reads; third-party access "is a breach of this Agreement"; interactions used to improve models with an opt-out |
| Vendor pricing and privacy pages: DeepSeek, MiniMax, Z.ai, Google AI Studio | living | The price and data columns in orchestration.md |
| Artificial Analysis model pages | Nov 2026 | Independent index and Terminal-Bench 4.0 figures |

## Added for the lead budget and for refactors and ports

| Source | Date | Used for |
|---|---|---|
| Session logs on one RantAI machine, 17,135 Claude Opus messages, read locally | Nov 2026 | Share of lead spend by token type; context per turn; thread length |
| Caveman skill README, `github.com/JuliusBrussee/caveman` | fetched Nov 2026 | Output tokens 6,983 with no instruction, 4,334 with "Answer concisely.", 4,119 with the skill; 8.5% fewer output tokens in a paired test on 86 tasks; prompts are never rewritten. The figures are the project's own and its README says they were not re-run. |
| Ladybird, "Ladybird adopts Rust, with help from AI" (`ladybird.org/posts/adopting-rust/`) and the February 2026 newsletter | Feb 2026 | About 25,000 lines ported in two weeks with coding agents; byte-for-byte identical output over 52,898 + 12,461 tests; a flag to run both pipelines in lockstep. Read through search summaries, not the page text. |
| Airbnb, "Accelerating Large-Scale Test Migration with LLMs" | Mar 2025 | 3,500 test files in six weeks; fixed steps with a check after each; 97% automatic. Read through secondary summaries. |
| Our own `rantai-kb` cutover runbook | 2026 | Reads, then writes, then retire; rollback plan; 21 recorded deliberate differences |

| Bun's rewrite in Rust: public coverage of PR #30412 and of talks by its author | May–Jul 2026 | About a million lines written by agents; the existing test suite and adversarial agent review as the gate; regressions after merge. Secondary sources; figures approximate. |
| T3 Code repository: `.macroscope/approvability.md`, `CONTRIBUTING.md`, `AGENTS.md` | Nov 2026 | What a review bot may approve alone; proof required by kind of change |

| Our own count of Rust file lengths in ripgrep, tokio, uv, ruff, rust-analyzer, deno and bun (shallow clones of each default branch, 10 Nov 2026) and in our Rust repositories | Nov 2026 | The Rust file-size limit. Non-test `.rs` files, lines before the first `#[cfg(test)]`; `tests/`, `benches/`, `examples/`, vendored and generated directories excluded. |

## Studies

| Source | Date | Finding used |
|---|---|---|
| "Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?", ETH Zurich, arXiv 2602.11988 (v3) | Feb 2026, rev. Sep 2026 | Generated context files did not improve success and raised cost over 20%; developer-written files +2.4 points (p = 0.21). The first version's headline was stronger than the revised one. |
| "ImpossibleBench", arXiv 2510.20270 | Oct 2025 | Models edit tests when task and tests conflict (50–76% on one benchmark); strict prompts, read-only tests and an abort option cut it sharply |
| arXiv 2607.21656, cross-model review on 116 tasks | Jul 2026 | A stronger reviewer raised a weaker author's pass rate (71.6% → 89.7%); a weaker reviewer lowered a stronger author's (91.4% → 82.8%) |
| arXiv 2610.21914 and 2601.02200, code health and agents | 2026 | Healthier code: lower token cost, fewer breaks under refactoring; file size explains part of it. Observational. |
| arXiv 2608.21747, specification format | Aug 2026 | Typed contracts tripled route coverage for the weakest model; no effect for the strongest. Single author, 90 trials. |
| GitClear code quality reports | 2025, 2026 | Copy-pasted lines up, refactored lines down. Vendor, observational. The 2026 figures are from the public abstract. |
| Aider architect / editor benchmarks | Sep 2024, Jan 2025 | A strong planner with a cheap editor matched or beat the strong model alone at a fraction of the cost |
| METR, experienced open-source developers RCT | Jul 2025, update Feb 2026 | Historical. It measured early-2025 tools, and METR now says the result no longer reflects current models. No rule here depends on it. |

## Looked for and not found

- Any study comparing vertical-slice with layered architecture for coding agents.
- Any study that typed errors or `Result` types help agents.
- Any study that `AI-NOTE`-style markers or module header blocks help agents.
- Any evidence for a 150–300 line file cap.
- The phrase "skeptical memory" in any Anthropic source. It appears in third-party write-ups of the
  March 2026 Claude Code source leak.
- Token counts for our own runs.
