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


def with_retries(
    op: Callable[[], Any],
    *,
    max_retries: int = MAX_RETRIES,
    base_delay: float = RETRY_DELAY,
    terminal_statuses: Collection[int] = (),
    retryable_statuses: Collection[int] = (429, 500, 502, 503, 504),
    logger=None,
    ctx: str = "operation",
) -> Tuple[Any, Optional[str]]:
    """Execute ``op`` with retry/backoff and return ``(result, error_message)``."""
    for attempt in range(max_retries):
        try:
            return op(), None
        except HttpError as e:
            status = getattr(getattr(e, "resp", None), "status", None)
            detail = getattr(e, "content", b"")
            detail_str = detail.decode(errors="ignore") if hasattr(detail, "decode") else str(e)
            if status in terminal_statuses:
                return None, f"{ctx} failed: HTTP {status}: {detail_str}"
            retryable = status in retryable_statuses
            if retryable and attempt < max_retries - 1:
                delay = (base_delay**attempt) * random.uniform(0.5, 1.5)
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
            return None, f"{ctx} failed: HTTP {status}: {detail_str}"
        except Exception as e:
            if attempt < max_retries - 1:
                delay = (base_delay**attempt) * random.uniform(0.5, 1.5)
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
            return None, f"{ctx} failed: {e}"
    return None, f"{ctx} failed: Max retries exceeded"
