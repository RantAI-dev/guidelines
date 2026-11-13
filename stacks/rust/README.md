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
- **Keep build time down.** The gate's budget is 10 minutes with a warm cache, 15 in CI, and Rust is
  where it is usually lost.
  - While iterating, check one crate: `cargo clippy -p <crate> --all-targets` and
    `cargo test -p <crate>`. Never `cargo clean` to get green.
  - Use one shared `CARGO_TARGET_DIR` across worktrees, so a new worker does not start cold. When
    several workers build on one machine, give each a share of the cores with `CARGO_BUILD_JOBS`.
  - Split by crate. A crate is what gets rebuilt: a change in a large crate rebuilds all of it and
    everything that depends on it.
  - Give each group of crates its own part in `scripts/check.sh` (`cargo test -p a -p b`), so a pull
    request tests only what it can break. A part must include the crates that depend on its crates:
    `cargo tree -i <crate> --workspace` lists them. The crates nearly everything uses go in
    `ALL_PATHS`; keep that list short, or every change runs every part.
  - Do not let one file collect every route, permission or error mapping. Each module registers its
    own, or that file puts every pull request in every part.
  - Find the slow part before guessing: `cargo build --timings` writes a report per crate.
  - Turn off default features you do not use (`default-features = false`), and remove unused
    dependencies with `cargo machete`.
  - In CI, cache the registry and `target/` keyed on `Cargo.lock`.
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
