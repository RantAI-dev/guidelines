# Spending less of the lead

The lead model is the scarce resource: it has a usage limit and the workers are flat-rate. This
page says where the lead's tokens go and how to spend fewer of them.

## Where the lead's tokens go

Measured from the session logs on one RantAI machine: 17,135 Claude Opus messages, November 2026,
weighted by list price.

| What | Share of spend |
|---|---|
| Re-reading cached context at the start of each turn | 66% |
| Writing new context into the cache | 20% |
| Output, including thinking, tool calls and code | 14% |
| Uncached input | under 1% |

The median turn read 105,000 tokens of context and wrote 486. In threads longer than 100 turns the
average context per turn was 288,000 tokens; in shorter threads it was 115,000.

So the lead's cost is roughly **turns × context size**. What it writes is a small part. We do not
know how a subscription limit weighs cached reads against output, so the exact shares may differ
there. The direction holds either way.

## What "caveman" teaches, and what it does not

Caveman is a popular Claude Code skill that makes the model answer in clipped phrases to save
tokens. Its own README is honest about the size of the effect:

- On ten questions with Opus 5.5, output fell from 6,983 tokens to 4,119. A plain "Answer
  concisely." got it to 4,334. Most of the gain is one sentence of instruction.
- An independent paired test on 86 tasks found 8.5% fewer output tokens and no loss of quality.
- It compresses output only, and it leaves code, commands, paths and errors untouched. Output is
  14% of our lead's spend, and most of that output is thinking, tool calls and plans.
- It never rewrites prompts, because compressed prompts made answers worse in the study it cites.

What we take from it: one line in the lead's runbook (answer first, no preamble, no recap, no
narration between tool calls), worth a few percent. What we do not do: install it, or let anyone
compress a plan, a brief or a review brief. Those are the prompts our cheap workers run on, and the
bench showed that their precision is what makes cheap workers succeed.

## The levers, largest first

1. **Fewer lead turns.**
   - Route small work without ceremony.
   - Start every worker in one turn, then end the turn. Never poll.
   - Let scripts gate: `guard-diff.sh` and `check.sh` decide, not a reading of the diff.
   - Send review findings to the author to reproduce and fix. The lead sees the outcome.
2. **Less context per turn.**
   - One feature per thread. A new thread starts small; a long one re-reads everything every turn.
   - Scouts read. A cheap model answers "where is X done" in 40 lines with anchors.
   - `scripts/audit.sh` reports a repository's state so that nobody reads it to find out.
   - Do not open a diff that passed the gate and a clean first-pass review, unless it touches a
     protected or risky path.
   - Keep `AGENTS.md` small. Every session reads it on every turn.
3. **Cheap first-pass review.** In the bench, DeepSeek and GLM-5.3 each found all four planted bugs
   with the review brief, the same as Opus. Where they differed was judgement on an ambiguous case,
   so the lead judges severity and disputes and does not do the reading.
4. **Medium effort by default.** High effort only for plans on auth, money, tenancy, migrations or
   deletes. This one is our judgement: we did not measure plan quality against effort.
5. **Say less.** The caveman lesson, in one line.

## A turn budget

Under these rules a delegated feature should take the lead about 10 to 15 turns in a fresh thread:

| Step | Lead turns |
|---|---|
| Route, scout, plan | 3 to 5 |
| Acceptance cases | 1 to 2 |
| Brief and start workers | 1 |
| Gate | 1 to 2 |
| Start first-pass review, pass findings to the author | 1 to 2 |
| Judge disputes | 0 to 2 |
| Integrate and open the pull request | 2 to 3 |

The median Opus thread in the logs was 43 turns, and one in ten passed 98. The budget is a target
to hold a thread against, not a measurement: nobody has yet run these rules end to end here.

## The desk thread

The one long-lived thread is where turns pile up, so it is where these rules matter most. It holds
the board and nothing else, starts a fresh child for every plan and every review, keeps its state
on the ticket, and is compacted every morning. See [desk-thread.md](desk-thread.md).

## What not to cut

- The plan's precision. It is why six different models all scored 21 of 21.
- Planner-written acceptance cases. They caught the one misread plan.
- The fresh context for review. A reviewer that has seen the lead's reasoning repeats it.
