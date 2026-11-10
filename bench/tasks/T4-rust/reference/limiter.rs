use std::collections::{HashMap, VecDeque};

use crate::{Clock, Config, ConfigError, Decision};

pub struct SlidingWindowLimiter<C: Clock> {
    config: Config,
    clock: C,
    high_water_ms: u64,
    hits: HashMap<String, VecDeque<u64>>,
}

impl<C: Clock> SlidingWindowLimiter<C> {
    /// # Errors
    /// `ZeroLimit` when `limit` is 0, otherwise `ZeroWindow` when `window_ms` is 0.
    pub fn new(config: Config, clock: C) -> Result<Self, ConfigError> {
        if config.limit == 0 {
            return Err(ConfigError::ZeroLimit);
        }
        if config.window_ms == 0 {
            return Err(ConfigError::ZeroWindow);
        }
        Ok(Self {
            config,
            clock,
            high_water_ms: 0,
            hits: HashMap::new(),
        })
    }

    fn now(&mut self) -> u64 {
        self.high_water_ms = self.high_water_ms.max(self.clock.now_ms());
        self.high_water_ms
    }

    fn drop_expired(queue: &mut VecDeque<u64>, now: u64, window_ms: u64) {
        while queue
            .front()
            .is_some_and(|t0| now >= t0.saturating_add(window_ms))
        {
            queue.pop_front();
        }
    }

    pub fn check(&mut self, key: &str) -> Decision {
        let now = self.now();
        let window_ms = self.config.window_ms;
        let limit = usize::try_from(self.config.limit).unwrap_or(usize::MAX);
        let queue = self.hits.entry(key.to_owned()).or_default();
        Self::drop_expired(queue, now, window_ms);

        if queue.len() < limit {
            queue.push_back(now);
            let left = limit.saturating_sub(queue.len());
            return Decision::Allowed {
                remaining: u32::try_from(left).unwrap_or(u32::MAX),
            };
        }
        let oldest = queue.front().copied().unwrap_or(now);
        Decision::Denied {
            retry_after_ms: oldest.saturating_add(window_ms).saturating_sub(now),
        }
    }

    pub fn purge_idle(&mut self) -> usize {
        let now = self.now();
        let window_ms = self.config.window_ms;
        let before = self.hits.len();
        self.hits.retain(|_, queue| {
            Self::drop_expired(queue, now, window_ms);
            !queue.is_empty()
        });
        before.saturating_sub(self.hits.len())
    }

    #[must_use]
    pub fn tracked_keys(&self) -> usize {
        self.hits.len()
    }
}
