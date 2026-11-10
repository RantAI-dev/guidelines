You are the developer on one task. You have no context other than this message and the repository.

Repository: {RUN_DIR} (a git repo, TypeScript + Bun). Work only inside that directory.
Read its AGENTS.md first. Its rules apply to you.

Task: implement the plan in docs/plans/T3-cancel-order.md.

Scope: src/features/orders/ only. Change nothing else.

Done means all of these:
- `bun run check` passes, and you ran it yourself after your last edit.
- The new behaviour has tests next to the code.
- The work is committed on the current branch and `git status` is clean.

Do not ask questions; nobody will answer. If something blocks you, stop and say so in the handoff.

End with a handoff as your final message, in exactly this shape:

STATUS: done | partial | blocked
CHECK: <the exact command you ran> -> pass | fail | not verified, with the test counts you saw
COMMITS: <short hashes>
FILES: <paths you changed>
DEVIATIONS: <where you departed from the plan and why, or "none">
NOT VERIFIED: <anything you did not run or could not confirm, or "none">
NOTES FOR REVIEWER: <risks, or things outside your scope that you noticed, or "none">
