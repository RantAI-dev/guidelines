use crate::{Clock, Config, ConfigError, Decision};

pub struct SlidingWindowLimiter<C: Clock> {
    config: Config,
    clock: C,
}

impl<C: Clock> SlidingWindowLimiter<C> {
    /// # Errors
    /// See docs/plans/T4-sliding-window.md.
    pub fn new(config: Config, clock: C) -> Result<Self, ConfigError> {
        Ok(Self { config, clock })
    }

    pub fn check(&mut self, _key: &str) -> Decision {
        let _ = (&self.config, &self.clock);
        Decision::Denied { retry_after_ms: 0 }
    }

    pub fn purge_idle(&mut self) -> usize {
        0
    }

    #[must_use]
    pub fn tracked_keys(&self) -> usize {
        0
    }
}
