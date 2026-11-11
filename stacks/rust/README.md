# Rust

The gate, from the workspace root:

```bash
cargo fmt --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace
```

Put the lints in `Cargo.toml` so they travel with the code (see `lints.toml`), not in a CI flag an
agent never sees.

- **No `unwrap`, `expect`, `panic!`, `todo!` or slice indexing outside tests.** Clippy denies them.
  Tests opt back in with `#![allow(clippy::unwrap_used, ...)]` at the top of the test module.
- **A suppression carries its reason:** `#[allow(clippy::too_many_lines, reason = "one state machine")]`.
  `clippy::allow_attributes_without_reason` makes the reason mandatory.
- **Keep build time down.** While iterating, check one crate: `cargo clippy -p <crate> --all-targets`
  and `cargo test -p <crate>`. Use one shared `CARGO_TARGET_DIR` across worktrees. Never `cargo clean`
  to get green.
- **File size.** The gate allows a Rust file 1,000 lines before its inline `#[cfg(test)]` module,
  against 600 for other languages. When a file nears it, move a type and its impls into a
  submodule, or move the tests into `tests.rs` beside it. Set `FILE_MAX_LINES_RS` to change it.
- **Commit `Cargo.lock`** for anything that is not a published library. A missing lockfile leaves an
  untracked file in every worker's checkout; we hit that in our own bench.
- **Boundaries by crate.** A pure core crate with no I/O, a ports crate, adapter crates, one
  composition root. Enforce it with a test or a small binary that reads `cargo metadata`, as
  `rantai-kb` does with `check-boundary`.
- **Errors.** `api_error.rs` builds the one error body from the generated `error_codes.rs`, for
  axum. Add `@emit rust <path>` to `.agents/error-codes.tsv`, run `scripts/error-codes.sh --write`,
  and copy the helper beside the result. The generated enum passes `cargo fmt --check` and
  `clippy::pedantic` as written. Handlers never pass `err.to_string()` as a message: log it.
