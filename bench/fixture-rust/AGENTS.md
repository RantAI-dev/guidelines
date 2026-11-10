# ratelimit

A per-key request limiter used by the API gateway. Rust, standard library only.

## Commands

| What | Command |
|---|---|
| Everything (run before handoff) | `cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` |
| Fast compile check while iterating | `cargo check` |

## Rules

1. No `unwrap`, `expect`, `panic!`, slice indexing or unchecked arithmetic outside `#[cfg(test)]`.
   `Cargo.toml` denies them in clippy. Use checked or saturating operations and `Option`/`Result`.
2. Never add `#[allow(...)]` or change `[lints]` to get green.
3. No new dependencies.
4. If the plan disagrees with the code, do not pick a side silently. Stop and report, or list it under
   `DEVIATIONS` in the handoff.
5. Stay inside the paths the task names.
6. "Green" means you ran the full command above after your last edit and read its output. Otherwise
   write `not verified`.
