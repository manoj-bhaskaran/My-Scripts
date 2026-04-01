"""Rate limiter utilities for Google Drive recovery operations."""

from __future__ import annotations

import logging
import time
from threading import Lock

from gdrive_constants import DEFAULT_BURST, DEFAULT_MAX_RPS


class RateLimiter:
    """Thread-safe request pacing with optional token bucket bursting."""

    def __init__(self, args, logger: logging.Logger) -> None:
        self.args = args
        self.logger = logger
        self._tb_tokens: float = 0.0
        self._tb_capacity: float = 0.0
        self._tb_last_refill: float | None = None
        self._tb_initialized: bool = False
        self._rl_lock = Lock()
        self._last_request_ts: float | None = None
        self._rl_diag_enabled: bool = bool(getattr(args, "rl_diagnostics", False))
        self._rl_calls: int = 0
        self._rl_window_start: float | None = None
        self._rl_diag_last_log: float | None = None

    def _should_use_token_bucket(self, burst: int) -> bool:
        """Return True if token bucket mode should be used."""
        return burst > 0

    def _init_token_bucket(self, now: float, burst: int) -> None:
        self._tb_capacity = float(burst)
        self._tb_tokens = self._tb_capacity
        self._tb_last_refill = now
        self._tb_initialized = True

    def _refill_token_bucket(self, now: float, max_rps: float) -> None:
        elapsed = max(0.0, now - (self._tb_last_refill or now))
        self._tb_last_refill = now
        self._tb_tokens = min(self._tb_capacity, self._tb_tokens + elapsed * max_rps)

    def _can_consume_token(self) -> bool:
        return self._tb_tokens >= 1.0

    def _consume_token(self) -> None:
        self._tb_tokens -= 1.0

    def _token_deficit(self) -> float:
        return max(0.0, 1.0 - self._tb_tokens)

    def _legacy_pacing(self, now: float, min_interval: float) -> float:
        last = self._last_request_ts
        if last is None or (now - last) >= min_interval:
            self._last_request_ts = now
            return 0.0
        return max(0.0, min_interval - (now - last))

    def _token_bucket_sleep(self, max_rps: float, burst: int, now: float) -> tuple[float, float]:
        """Handle token bucket logic, sleeping if needed, and return (tokens_snapshot, cap_snapshot)."""
        while True:
            with self._rl_lock:
                if not self._tb_initialized:
                    self._init_token_bucket(now, burst)
                else:
                    self._refill_token_bucket(now, max_rps)
                if self._can_consume_token():
                    self._consume_token()
                    return self._tb_tokens, self._tb_capacity
                sleep_for = self._token_deficit() / max_rps
            if sleep_for > 0:
                time.sleep(sleep_for)
            now = time.monotonic()

    def _legacy_pacing_sleep(self, now: float, min_interval: float) -> None:
        """Handle legacy fixed-interval pacing, sleeping if needed."""
        while True:
            with self._rl_lock:
                delay = self._legacy_pacing(now, min_interval)
                if abs(delay) < 1e-9:
                    return
            if delay > 0.0:
                time.sleep(delay)
            now = time.monotonic()

    def wait(self) -> None:
        """Global request pacing shared across threads."""
        max_rps = float(getattr(self.args, "max_rps", DEFAULT_MAX_RPS) or 0)
        if max_rps <= 0:
            return
        burst = int(getattr(self.args, "burst", DEFAULT_BURST) or 0)
        now = time.monotonic()
        if self._should_use_token_bucket(burst):
            tokens_snapshot, cap_snapshot = self._token_bucket_sleep(max_rps, burst, now)
            self._rl_diag_tick(max_rps, tokens_snapshot, cap_snapshot)
            return
        min_interval = 1.0 / max_rps
        self._legacy_pacing_sleep(now, min_interval)
        self._rl_diag_tick(max_rps, -1.0, -1.0)

    def _rl_diag_tick(self, max_rps: float, tokens_snapshot: float, cap_snapshot: float) -> None:
        """Emit sampled diagnostics for the rate limiter when enabled and DEBUG logging is active."""
        if not self._rl_diag_enabled or not self.logger.isEnabledFor(logging.DEBUG):
            return
        now = time.monotonic()
        self._rl_calls += 1
        if self._rl_window_start is None:
            self._rl_window_start = now
            self._rl_diag_last_log = now
            return
        window = max(1e-6, now - self._rl_window_start)
        if (self._rl_diag_last_log is None) or (now - self._rl_diag_last_log >= 5.0):
            observed_rps = self._rl_calls / window
            is_token_bucket = (
                tokens_snapshot is not None
                and cap_snapshot is not None
                and tokens_snapshot > -0.5
                and cap_snapshot > -0.5
            )
            if is_token_bucket:
                self.logger.debug(
                    "RL diag: observed_rps=%.2f target=%.2f tokens=%.2f cap=%.2f window=%.1fs",
                    observed_rps,
                    max_rps,
                    tokens_snapshot,
                    cap_snapshot,
                    window,
                )
            else:
                self.logger.debug(
                    "RL diag: observed_rps=%.2f target=%.2f mode=fixed-interval window=%.1fs",
                    observed_rps,
                    max_rps,
                    window,
                )
            self._rl_diag_last_log = now
