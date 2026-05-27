"""Query and filter helpers for DriveTrashDiscovery."""

from __future__ import annotations

from datetime import timezone
from typing import Any, Mapping, Optional, Sequence

from dateutil import parser as date_parser

from gdrive_constants import EXTENSION_MIME_TYPES


def normalize_extension(ext: str) -> str:
    """Normalize extension tokens while preserving multi-segment suffixes."""
    return (ext or "").lower().strip(".")


def normalize_extension_last_segment(ext: str) -> str:
    """Normalize extension tokens to the last segment for MIME lookup."""
    ext_normalized = normalize_extension(ext)
    return ext_normalized.split(".")[-1] if ext_normalized else ""


def build_mime_conditions(extensions: Optional[Sequence[str]]) -> list[str]:
    if not extensions:
        return []
    return [
        f"mimeType = '{EXTENSION_MIME_TYPES[last_seg]}'"
        for ext in extensions
        for last_seg in [normalize_extension_last_segment(ext)]
        if last_seg in EXTENSION_MIME_TYPES
    ]


def build_discovery_query(extensions: Optional[Sequence[str]], after_date: Optional[str]) -> str:
    query_parts = ["trashed=true"]
    mime_conditions = build_mime_conditions(extensions)
    if mime_conditions:
        query_parts.append(f"({' or '.join(mime_conditions)})")
    if after_date:
        query_parts.append(f"modifiedTime > '{after_date}'")
    return " and ".join(query_parts)


def matches_extension_filter(filename: str, extensions: Optional[Sequence[str]]) -> bool:
    if not extensions or not filename:
        return True
    filename_lower = filename.lower()
    return any(filename_lower.endswith(f".{normalize_extension(ext)}") for ext in extensions)


def matches_time_filter(item_data: Mapping[str, Any], after_date: Optional[str]) -> bool:
    if not after_date:
        return True
    modified_dt = date_parser.parse(item_data.get("modifiedTime", ""))
    after_dt = date_parser.parse(after_date)
    if not hasattr(modified_dt, "tzinfo") or not hasattr(after_dt, "tzinfo"):
        return True
    if modified_dt.tzinfo is None:
        modified_dt = modified_dt.replace(tzinfo=timezone.utc)
    if after_dt.tzinfo is None:
        after_dt = after_dt.replace(tzinfo=timezone.utc)
    return modified_dt > after_dt
