"""
Validator helpers for geographic coordinates and timestamps.

Python requirement: 3.10+
This module uses PEP 604 union types (e.g., float | int | str | None). If you need
to run on Python 3.9, replace these with typing.Union / typing.Optional or use
an earlier 1.5.x release line.
"""

from datetime import datetime


def validate_latitude(value: float | int | str | None) -> bool:
    """Return ``True`` when *value* is a valid latitude between -90 and 90 degrees."""

    if value is None:
        return False
    try:
        val = float(value)
    except (TypeError, ValueError):
        return False
    return -90.0 <= val <= 90.0


def validate_longitude(value: float | int | str | None) -> bool:
    """Return ``True`` when *value* is a valid longitude between -180 and 180 degrees."""

    if value is None:
        return False
    try:
        val = float(value)
    except (TypeError, ValueError):
        return False
    return -180.0 <= val <= 180.0


def validate_timestamp(ts: str | None) -> bool:
    """Return ``True`` when *ts* is a parseable ISO 8601 timestamp (with or without ``Z``)."""

    if not isinstance(ts, str):
        return False
    try:
        normalized = ts.replace("Z", "+00:00")
        datetime.fromisoformat(normalized)
        return True
    except (ValueError, TypeError):
        return False
