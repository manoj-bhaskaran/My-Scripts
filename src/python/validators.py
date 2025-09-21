"""
Validator helpers for extension tokens and policy normalization.

Python requirement: 3.10+
This module uses PEP 604 union types (e.g., Sequence[str] | None). If you need
to run on Python 3.9, replace these with typing.Union / typing.Optional or use
an earlier 1.5.x release line.
"""
from __future__ import annotations

import re
from typing import Iterable, List, Mapping, Sequence, Tuple, Optional, Dict


def _normalize_extension_token(token: str) -> str:
    """
    Normalize a raw extension token to a canonical, comparison-friendly form.

    Steps:
      1. Strip surrounding whitespace.
      2. Lowercase.
      3. Remove all leading dots (e.g., ``".tar.gz" -> "tar.gz"``).
      4. Collapse multiple consecutive dots to a single dot (``"a..b" -> "a.b"``).

    Parameters
    ----------
    token : str
        Raw user token, potentially with dots/whitespace/case variation.

    Returns
    -------
    str
        Canonicalized token or empty string when input is not a `str`.

    Examples
    --------
    >>> _normalize_extension_token(". JPG ")
    'jpg'
    >>> _normalize_extension_token("..tar..gz")
    'tar.gz'
    """
    if not isinstance(token, str):
        return ""
    token = token.strip().lower()
    token = token.strip(".")
    token = re.sub(r"\.+", ".", token)
    return token


def _is_invalid_extension_token(token: str) -> bool:
    """
    Quick screen for obviously invalid extension tokens.

    Disallows:
      - Non-string/empty values (handled by caller, here treated as invalid)
      - Whitespace, commas, asterisks, slashes, or backslashes
        (e.g., ``"jpg, png"`` or ``"*.pdf"`` or ``"a/b"``)

    Parameters
    ----------
    token : str
        Canonicalized or raw token to check.

    Returns
    -------
    bool
        ``True`` when the token is structurally invalid and should be rejected.
    """
    if not token or not isinstance(token, str):
        return True
    if any(c in token for c in " ,*/\\"):
        return True
    return False


def _is_valid_extension_segments(token: str) -> bool:
    """
    Validate token segments for allowed length and charset.

    Rules:
      - Token is split by dots into segments.
      - Each segment must be 1..10 characters.
      - Allowed characters are lowercase alphanumerics ``[a-z0-9]`` only.
      - Multi-segment tokens are allowed (e.g., ``tar.gz``, ``min.js``).

    Parameters
    ----------
    token : str
        The extension token (normalized or raw).

    Returns
    -------
    bool
        ``True`` when every segment passes validation; otherwise ``False``.
    """
    if not token:
        return False
    segments = token.split('.')
    for seg in segments:
        if not (1 <= len(seg) <= 10):
            return False
        if not re.fullmatch(r'[a-z0-9]+', seg):
            return False
    return True


def _dedupe_preserve_order(seq: Iterable[str]) -> List[str]:
    """
    Remove duplicates while preserving the first occurrence order.

    Parameters
    ----------
    seq : Iterable[str]
        Any iterable of strings.

    Returns
    -------
    List[str]
        New list with duplicates removed, order preserved.
    """
    seen = set()
    result: List[str] = []
    for item in seq:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def validate_extensions(
    raw_exts: Sequence[str] | None,
    mime_map: Mapping[str, str],
) -> Tuple[List[str], List[str], List[str]]:
    """
    Normalize and validate user-supplied extension tokens.

    This function is independent of argparse and can be used in tests directly.
    It accepts raw tokens, normalizes them (see :func:`_normalize_extension_token`),
    rejects invalid syntax (see :func:`_is_invalid_extension_token` and
    :func:`_is_valid_extension_segments`), deduplicates while preserving order,
    and emits warnings when server-side MIME narrowing is not possible.

    Parameters
    ----------
    raw_exts : Sequence[str] | None
        Raw tokens like ``["jpg", ".png", "tar.gz"]`` or ``None`` for “no filter”.
    mime_map : Mapping[str, str]
        Mapping from a **single** extension segment (e.g., ``"jpg"``) to a MIME type.
        Only the **last** segment of multi-segment tokens participates in server-side
        narrowing (client-side still checks the full suffix).

    Returns
    -------
    Tuple[List[str], List[str], List[str]]
        ``(cleaned_exts, warnings, errors)`` where:
          - ``cleaned_exts``: normalized, de-duplicated tokens (multi-segment preserved).
          - ``warnings``: informational notes when tokens won’t narrow server-side queries.
          - ``errors``: user-actionable validation failures (e.g., illegal characters).
    """
    if not raw_exts:
        return [], [], []

    invalid: List[str] = []
    cleaned: List[str] = []
    for raw in raw_exts:
        tok = _normalize_extension_token(raw)
        if _is_invalid_extension_token(tok) or not tok or not _is_valid_extension_segments(tok):
            invalid.append(repr(raw))
            continue
        # Keep multi-segment token as-is; server-side lookup will use last segment
        cleaned.append(".".join([s for s in tok.split('.') if s != ""]))

    if invalid:
        return [], [], [f"Invalid --extensions value(s): {', '.join(invalid)}"]

    deduped = _dedupe_preserve_order(cleaned)

    # Build warnings:
    warnings: List[str] = []
    unknown: List[str] = []
    for e in deduped:
        last_seg = e.split('.')[-1] if e else e
        if last_seg not in mime_map:
            unknown.append(e)
    if unknown:
        warnings.append(
            "Note: unknown extension(s) will not narrow server-side queries; "
            "client-side filename filtering will apply instead: " + ", ".join(unknown)
        )
        # (v1.5.8) Messaging unchanged; emission behavior handled by caller (stderr/log level).
        if any('.' in e for e in unknown):
            warnings.append(
                "Multi-segment extensions (e.g., tar.gz) are matched client-side against the full suffix; "
                "server-side MIME narrowing uses the last segment when mapped."
            )

    return deduped, warnings, []

def _levenshtein(a: str, b: str) -> int:
    """Simple Levenshtein distance (O(len(a)*len(b))) without external deps."""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            ins = cur[j-1] + 1
            dele = prev[j] + 1
            sub = prev[j-1] + (ca != cb)
            cur.append(min(ins, dele, sub))
        prev = cur
    return prev[-1]

def _suggest_token(raw: str, candidates: Sequence[str]) -> Optional[str]:
    """Return best suggestion within distance ≤ 2, else None."""
    try:
        key = re.sub(r'[\s_-]+', '', str(raw).strip().lower())
    except Exception:
        key = str(raw or "").strip().lower()
    best: Tuple[int, Optional[str]] = (10**9, None)
    for c in candidates:
        d = _levenshtein(key, c)
        if d < best[0]:
            best = (d, c)
            if d == 0:
                break
    return best[1] if best[0] <= 2 else None

def normalize_policy_token(
    raw: str | None,
    *,
    strict: bool,
    aliases: Mapping[str, str],
    default_value: str,
) -> Tuple[str, List[str], List[str], Dict[str, dict]]:
    """
    Normalize a post-restore policy token using provided aliases.

    Returns: (normalized_value, warnings, errors, telemetry)
      - if strict and unknown -> errors contains message
      - if not strict and unknown -> fallback to default_value and warnings contains note
      - telemetry includes an 'unknown_policy' object when unknown
    """
    if raw is None or raw == "":
        return default_value, [], [], {}

    key = re.sub(r'[\s_-]+', '', str(raw).strip().lower())
    if key in aliases:
        return aliases[key], [], [], {}

    # Unknown token handling
    suggestion = _suggest_token(key, list(aliases.keys()))
    suggestion_text = f" Did you mean '{suggestion}'?" if suggestion else ""

    telemetry = {"unknown_policy": {"token": str(raw), "normalized": key, "suggestion": suggestion}}

    if strict:
        return default_value, [], [
            f"Unknown --post-restore-policy value '{raw}'. Use one of: retain | trash | delete (aliases allowed).{suggestion_text}"
        ], telemetry

    return (
        default_value,
        [f"Unknown --post-restore-policy '{raw}'. Falling back to '{default_value}'.{suggestion_text} (Tip: use --strict-policy to make this an error.)"],
        [],
        telemetry,
    )
