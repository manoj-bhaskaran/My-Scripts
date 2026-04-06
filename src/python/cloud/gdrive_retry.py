"""Shared retry helper for Google Drive operations."""

from __future__ import annotations

import random
import time
from typing import Any, Callable, Collection, Optional, Tuple

try:
    from googleapiclient.errors import HttpError
except Exception:

    class HttpError(Exception):
        """Fallback HttpError for test environments without googleapiclient."""

        def __init__(self, resp=None, content=b"", *args, **kwargs):
            super().__init__(*args)
            self.resp = resp
            self.content = content


from gdrive_constants import MAX_RETRIES, RETRY_DELAY


def _can_retry(attempt: int, max_retries: int) -> bool:
    return attempt < max_retries - 1


def _extract_http_error_parts(e: HttpError) -> Tuple[Optional[int], str]:
    status = getattr(getattr(e, "resp", None), "status", None)
    detail = getattr(e, "content", b"")
    detail_str = detail.decode(errors="ignore") if hasattr(detail, "decode") else str(e)
    return status, detail_str


def _compute_backoff_delay(base_delay: float, attempt: int) -> float:
    return (base_delay**attempt) * random.uniform(0.5, 1.5)


def _format_http_failure(ctx: str, status: Optional[int], detail: str) -> str:
    return f"{ctx} failed: HTTP {status}: {detail}"


def with_retries(
    op: Callable[[], Any],
    *,
    max_retries: int = MAX_RETRIES,
    base_delay: float = RETRY_DELAY,
    terminal_statuses: Collection[int] = (),
    retryable_statuses: Collection[int] = (429, 500, 502, 503, 504),
    logger=None,
    ctx: str = "operation",
) -> Tuple[Any, Optional[str], Optional[int]]:
    """Execute ``op`` with retry/backoff and return ``(result, error_message, http_status)``."""
    for attempt in range(max_retries):
        try:
            return op(), None, None
        except HttpError as e:
            status, detail_str = _extract_http_error_parts(e)
            if status in terminal_statuses:
                return None, _format_http_failure(ctx, status, detail_str), status
            if status in retryable_statuses and _can_retry(attempt, max_retries):
                delay = _compute_backoff_delay(base_delay, attempt)
                if logger:
                    logger.warning(
                        "%s failed with HTTP %s (attempt %d/%d). Retrying in %.2fs.",
                        ctx,
                        status,
                        attempt + 1,
                        max_retries,
                        delay,
                    )
                time.sleep(delay)
                continue
            return None, _format_http_failure(ctx, status, detail_str), status
        except Exception as e:
            if _can_retry(attempt, max_retries):
                delay = _compute_backoff_delay(base_delay, attempt)
                if logger:
                    logger.warning(
                        "%s failed (attempt %d/%d): %s. Retrying in %.2fs.",
                        ctx,
                        attempt + 1,
                        max_retries,
                        e,
                        delay,
                    )
                time.sleep(delay)
                continue
            return None, f"{ctx} failed: {e}", None
    return None, f"{ctx} failed: Max retries exceeded", None
