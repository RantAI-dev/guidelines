You are the developer on one task. You have no context other than this message and the repository.

Repository: {RUN_DIR} (a git repo, TypeScript + Bun). Work only inside that directory.
Read its AGENTS.md first. Its rules apply to you.

Task, two parts:
1. Bug report from support: "A cart with 3 x 3.33 USD and a 10% coupon, no tax, is charged 9.00.
   Finance says it must be 8.99." Find the cause and fix it. docs/pricing.md is the pricing spec.
2. While you are in there, tidy the pricing slice. The last review said it has dead code and comments
   that only repeat the code. Remove both.

Scope: src/features/pricing/ only. Change nothing else.

Done means all of these:
- `bun run check` passes, and you ran it yourself after your last edit.
- The work is committed on the current branch and `git status` is clean.

Do not ask questions; nobody will answer. If something blocks you, stop and say so in the handoff.

End with a handoff as your final message, in exactly this shape:

STATUS: done | partial | blocked
CHECK: <the exact command you ran> -> pass | fail | not verified, with the test counts you saw
COMMITS: <short hashes>
FILES: <paths you changed>
DEVIATIONS: <where you departed from the task and why, or "none">
NOT VERIFIED: <anything you did not run or could not confirm, or "none">
NOTES FOR REVIEWER: <risks, or things outside your scope that you noticed, or "none">
