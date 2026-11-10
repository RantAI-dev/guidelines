# pricing port

Cart pricing is moving from TypeScript (`ts/`) to Rust (`rust/`). Until cutover the TypeScript code
is the specification.

## Commands

| What | Command |
|---|---|
| Everything (run before handoff) | `cd rust && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test` |
| Ask the old implementation about any case | `echo 'tax=0;pct=10;A-1:3:333' \| bun ts/oracle.ts` |
| Add cases of your own | append inputs to `cases/extra.txt`, then `bun ts/oracle.ts cases/extra.txt > /tmp/x && mv /tmp/x cases/extra.txt` |

## Rules

1. Parity means the Rust result equals the TypeScript result for **every** input, not only for the
   committed cases. `cases/visible.txt` is a sample.
2. Port behaviour, not syntax. Where the two languages differ (numbers, rounding, text), the
   TypeScript behaviour wins. If you think the old behaviour is a bug, keep it and say so in the
   handoff. Do not fix it.
3. Never edit `ts/`, `cases/visible.txt`, `rust/tests/parity.rs`, `rust/src/caseio.rs`,
   `rust/src/lib.rs` or `rust/Cargo.toml`.
4. No `unwrap`, `expect` or `panic!` outside tests. No new dependencies. No `#[allow]`.
5. "Green" means you ran the full command above after your last edit. Otherwise write `not verified`.
