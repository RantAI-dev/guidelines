#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::arithmetic_side_effects)]
use std::cell::Cell;
use std::rc::Rc;

use ratelimit::{Clock, Config, ConfigError, Decision, SlidingWindowLimiter};

#[derive(Clone, Default)]
struct Fake(Rc<Cell<u64>>);
impl Fake {
    fn set(&self, t: u64) {
        self.0.set(t);
    }
}
impl Clock for Fake {
    fn now_ms(&self) -> u64 {
        self.0.get()
    }
}

fn limiter(limit: u32, window_ms: u64) -> (SlidingWindowLimiter<Fake>, Fake) {
    let clock = Fake::default();
    let l = SlidingWindowLimiter::new(Config { limit, window_ms }, clock.clone())
        .unwrap_or_else(|_| panic!("valid config"));
    (l, clock)
}

#[test]
fn h01_zero_limit_and_zero_window() {
    let c = Fake::default();
    assert!(matches!(
        SlidingWindowLimiter::new(Config { limit: 0, window_ms: 10 }, c.clone()),
        Err(ConfigError::ZeroLimit)
    ));
    assert!(matches!(
        SlidingWindowLimiter::new(Config { limit: 1, window_ms: 0 }, c.clone()),
        Err(ConfigError::ZeroWindow)
    ));
    assert!(matches!(
        SlidingWindowLimiter::new(Config { limit: 0, window_ms: 0 }, c),
        Err(ConfigError::ZeroLimit)
    ));
}

#[test]
fn h02_remaining_counts_down_then_denies() {
    let (mut l, _c) = limiter(3, 1000);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 2 });
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 1 });
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
    assert_eq!(l.check("a"), Decision::Denied { retry_after_ms: 1000 });
}

#[test]
fn h03_retry_after_is_time_until_oldest_expires() {
    let (mut l, c) = limiter(2, 1000);
    c.set(100);
    l.check("a");
    c.set(400);
    l.check("a");
    c.set(650);
    assert_eq!(l.check("a"), Decision::Denied { retry_after_ms: 450 });
}

#[test]
fn h04_exact_boundary_is_allowed() {
    let (mut l, c) = limiter(1, 1000);
    c.set(5);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
    c.set(1004);
    assert_eq!(l.check("a"), Decision::Denied { retry_after_ms: 1 });
    c.set(1005);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
}

#[test]
fn h05_window_slides_it_is_not_fixed_buckets() {
    let (mut l, c) = limiter(2, 1000);
    c.set(0);
    l.check("a");
    c.set(600);
    l.check("a");
    c.set(1000);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
    c.set(1100);
    assert_eq!(l.check("a"), Decision::Denied { retry_after_ms: 500 });
}

#[test]
fn h06_denied_requests_are_not_recorded() {
    let (mut l, c) = limiter(1, 1000);
    c.set(0);
    l.check("a");
    for t in [100, 500, 900, 999] {
        c.set(t);
        assert!(matches!(l.check("a"), Decision::Denied { .. }));
    }
    c.set(1000);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
}

#[test]
fn h07_keys_are_independent_and_empty_key_is_fine() {
    let (mut l, _c) = limiter(1, 1000);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
    assert_eq!(l.check("b"), Decision::Allowed { remaining: 0 });
    assert_eq!(l.check(""), Decision::Allowed { remaining: 0 });
    assert!(matches!(l.check("a"), Decision::Denied { .. }));
    assert!(matches!(l.check(""), Decision::Denied { .. }));
}

#[test]
fn h08_clock_going_backwards_is_clamped() {
    let (mut l, c) = limiter(1, 1000);
    c.set(5000);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
    c.set(100);
    assert_eq!(l.check("a"), Decision::Denied { retry_after_ms: 1000 });
    assert_eq!(l.check("b"), Decision::Allowed { remaining: 0 });
    c.set(5999);
    assert_eq!(l.check("b"), Decision::Denied { retry_after_ms: 1 });
    c.set(6000);
    assert_eq!(l.check("b"), Decision::Allowed { remaining: 0 });
}

#[test]
fn h09_huge_window_saturates_instead_of_overflowing() {
    let (mut l, c) = limiter(1, u64::MAX);
    c.set(10);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
    c.set(20);
    assert_eq!(l.check("a"), Decision::Denied { retry_after_ms: u64::MAX - 20 });
}

#[test]
fn h10_readings_near_u64_max_do_not_panic() {
    let (mut l, c) = limiter(2, 1000);
    c.set(u64::MAX - 10);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 1 });
    c.set(u64::MAX - 5);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: 0 });
    assert_eq!(l.check("a"), Decision::Denied { retry_after_ms: 5 });
    c.set(u64::MAX);
    let _ = l.check("a");
    let _ = l.purge_idle();
}

#[test]
fn h11_purge_idle_drops_only_expired_keys() {
    let (mut l, c) = limiter(2, 1000);
    c.set(0);
    l.check("old");
    c.set(900);
    l.check("fresh");
    assert_eq!(l.tracked_keys(), 2);
    assert_eq!(l.purge_idle(), 0);
    c.set(1000);
    assert_eq!(l.purge_idle(), 1);
    assert_eq!(l.tracked_keys(), 1);
    c.set(1900);
    assert_eq!(l.purge_idle(), 1);
    assert_eq!(l.tracked_keys(), 0);
    assert_eq!(l.purge_idle(), 0);
}

#[test]
fn h12_purge_uses_the_clamped_clock() {
    let (mut l, c) = limiter(1, 1000);
    c.set(2000);
    l.check("a");
    c.set(0);
    assert_eq!(l.purge_idle(), 0);
    assert_eq!(l.tracked_keys(), 1);
}

#[test]
fn h13_large_limit_does_not_preallocate_or_overflow() {
    let (mut l, _c) = limiter(u32::MAX, 1000);
    assert_eq!(l.check("a"), Decision::Allowed { remaining: u32::MAX - 1 });
    assert_eq!(l.check("a"), Decision::Allowed { remaining: u32::MAX - 2 });
}
