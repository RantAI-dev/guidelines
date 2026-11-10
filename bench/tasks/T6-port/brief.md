You are the developer on one task. You have no context other than this message and the repository.

Repository: {RUN_DIR} (a git repo: TypeScript in ts/, Rust in rust/). Work only inside that directory.
Read its AGENTS.md first. Its rules apply to you.

Task: port `priceCart` from ts/price-cart.ts to Rust, in rust/src/price.rs. The stub there returns
an error for everything. The types and the case harness are already written.

The TypeScript code is the specification. For every input, the Rust result must equal the
TypeScript result. cases/visible.txt holds a few examples. It is not the full set: the port will be
checked against several hundred cases you have not seen. You can ask the old implementation about
any case you invent with `bun ts/oracle.ts` (see AGENTS.md), and you should.

Scope: rust/src/price.rs, new files under rust/tests/, and cases/extra.txt. Change nothing else.

Done means all of these:
- `cd rust && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` passes,
  and you ran it yourself after your last edit.
- The work is committed on the current branch and `git status` is clean.

Do not ask questions; nobody will answer. If something blocks you, stop and say so in the handoff.

End with a handoff as your final message, in exactly this shape:

STATUS: done | partial | blocked
CHECK: <the exact command you ran> -> pass | fail | not verified, with the test counts you saw
COMMITS: <short hashes>
FILES: <paths you changed>
DEVIATIONS: <where the Rust behaviour knowingly differs from the TypeScript, or "none">
NOT VERIFIED: <anything you did not run or could not confirm, or "none">
NOTES FOR REVIEWER: <behaviour of the old code that looks like a bug, risks, or "none">
