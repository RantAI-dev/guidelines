//! Per-key sliding-window request limiter.

mod limiter;

pub use limiter::SlidingWindowLimiter;

/// Source of time. The gateway passes a monotonic clock; tests pass a fake.
pub trait Clock {
    fn now_ms(&self) -> u64;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Config {
    /// Requests allowed per key inside one window.
    pub limit: u32,
    pub window_ms: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConfigError {
    ZeroLimit,
    ZeroWindow,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Decision {
    Allowed { remaining: u32 },
    Denied { retry_after_ms: u64 },
}
