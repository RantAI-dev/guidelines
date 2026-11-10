# Plan T4 — sliding-window limiter

## Goal

`SlidingWindowLimiter` in `src/limiter.rs` is a stub that denies everything. Implement it. The public
API in `src/lib.rs` and the method signatures in `src/limiter.rs` are fixed; the gateway already
compiles against them.

## Behaviour

`new(config, clock)`
- `limit == 0` → `Err(ConfigError::ZeroLimit)`. Otherwise `window_ms == 0` → `Err(ConfigError::ZeroWindow)`.

`check(key)`
- `now` is the clock reading, except that time never goes backwards: if the clock returns less than
  the highest reading this limiter has seen, use that highest reading instead.
- An earlier allowed request made at `t0` still counts while `now < t0 + window_ms`. At exactly
  `t0 + window_ms` it no longer counts. The sum saturates at `u64::MAX`.
- With `count` such requests for this key: if `count < limit`, record this request at `now` and
  return `Allowed { remaining: limit - count - 1 }`.
- Otherwise return `Denied { retry_after_ms }`, the time until the oldest counted request stops
  counting. A denied request is not recorded.
- Keys do not affect each other. Any string is a valid key, the empty string too.

`purge_idle()`
- Drops every key that has no counted request at the current `now` (same clock rule as `check`) and
  returns how many keys it dropped.

`tracked_keys()`
- Number of keys the limiter currently holds state for. `check` may leave an idle key in place;
  `purge_idle` is what removes it.

Nothing here may panic for any `Config` that `new` accepts, any key and any clock reading,
including `window_ms == u64::MAX` and readings near `u64::MAX`.

## Out of scope

Thread safety, persistence, distributed limiting.
