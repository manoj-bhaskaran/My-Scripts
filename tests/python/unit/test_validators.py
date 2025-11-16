"""
Unit tests for src/python/validators.py

Tests input validation functions including extension token normalization,
policy token normalization, and related helper functions.
"""

import pytest
import sys
from pathlib import Path

# Add src path to allow imports
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "src" / "python"))

from validators import (
    _normalize_extension_token,
    _is_invalid_extension_token,
    _is_valid_extension_segments,
    _dedupe_preserve_order,
    validate_extensions,
    normalize_policy_token,
    _levenshtein,
    _suggest_token,
)


class TestNormalizeExtensionToken:
    """Tests for _normalize_extension_token function."""

    def test_basic_normalization(self):
        """Test basic token normalization."""
        assert _normalize_extension_token(" JPG ") == "jpg"
        assert _normalize_extension_token(".jpg") == "jpg"
        assert _normalize_extension_token("..tar..gz") == "tar.gz"

    def test_case_insensitive(self):
        """Test case normalization."""
        assert _normalize_extension_token("PNG") == "png"
        assert _normalize_extension_token("TaR.Gz") == "tar.gz"

    def test_leading_dots_removed(self):
        """Test removal of leading dots."""
        assert _normalize_extension_token(".txt") == "txt"
        assert _normalize_extension_token("...pdf") == "pdf"

    def test_consecutive_dots_collapsed(self):
        """Test collapsing of consecutive dots."""
        assert _normalize_extension_token("a..b") == "a.b"
        assert _normalize_extension_token("tar...gz") == "tar.gz"

    def test_non_string_input(self):
        """Test handling of non-string input."""
        assert _normalize_extension_token(None) == ""
        assert _normalize_extension_token(123) == ""
        assert _normalize_extension_token([]) == ""


class TestIsInvalidExtensionToken:
    """Tests for _is_invalid_extension_token function."""

    def test_valid_tokens(self):
        """Test that valid tokens are not marked as invalid."""
        assert not _is_invalid_extension_token("jpg")
        assert not _is_invalid_extension_token("tar.gz")

    def test_invalid_whitespace(self):
        """Test rejection of tokens with whitespace."""
        assert _is_invalid_extension_token("jpg png")
        assert _is_invalid_extension_token("a b")

    def test_invalid_special_chars(self):
        """Test rejection of tokens with invalid special characters."""
        assert _is_invalid_extension_token("*.pdf")
        assert _is_invalid_extension_token("a/b")
        assert _is_invalid_extension_token("a\\b")
        assert _is_invalid_extension_token("jpg,png")

    def test_empty_token(self):
        """Test rejection of empty tokens."""
        assert _is_invalid_extension_token("")
        assert _is_invalid_extension_token(None)


class TestIsValidExtensionSegments:
    """Tests for _is_valid_extension_segments function."""

    def test_valid_single_segment(self):
        """Test valid single-segment tokens."""
        assert _is_valid_extension_segments("jpg")
        assert _is_valid_extension_segments("pdf")
        assert _is_valid_extension_segments("txt")

    def test_valid_multi_segment(self):
        """Test valid multi-segment tokens."""
        assert _is_valid_extension_segments("tar.gz")
        assert _is_valid_extension_segments("min.js")

    def test_segment_length_limits(self):
        """Test segment length validation (1-10 characters)."""
        assert _is_valid_extension_segments("a")  # min length
        assert _is_valid_extension_segments("abcdefghij")  # max length
        assert not _is_valid_extension_segments("")  # too short
        assert not _is_valid_extension_segments("abcdefghijk")  # too long
        assert not _is_valid_extension_segments("abc.abcdefghijk")  # one segment too long

    def test_alphanumeric_only(self):
        """Test that only lowercase alphanumerics are allowed."""
        assert _is_valid_extension_segments("abc123")
        assert not _is_valid_extension_segments("abc_def")  # underscore
        assert not _is_valid_extension_segments("abc-def")  # hyphen
        assert not _is_valid_extension_segments("ABC")  # uppercase

    def test_empty_token(self):
        """Test rejection of empty token."""
        assert not _is_valid_extension_segments("")


class TestDedupePreserveOrder:
    """Tests for _dedupe_preserve_order function."""

    def test_no_duplicates(self):
        """Test list with no duplicates."""
        assert _dedupe_preserve_order(["a", "b", "c"]) == ["a", "b", "c"]

    def test_with_duplicates(self):
        """Test deduplication while preserving order."""
        assert _dedupe_preserve_order(["a", "b", "a", "c", "b"]) == ["a", "b", "c"]

    def test_preserves_first_occurrence(self):
        """Test that first occurrence is preserved."""
        result = _dedupe_preserve_order(["jpg", "png", "jpg", "gif"])
        assert result == ["jpg", "png", "gif"]
        assert result.index("jpg") == 0

    def test_empty_sequence(self):
        """Test empty sequence."""
        assert _dedupe_preserve_order([]) == []


class TestValidateExtensions:
    """Tests for validate_extensions function."""

    def test_none_input(self):
        """Test None input returns empty lists."""
        result = validate_extensions(None, {})
        assert result == ([], [], [])

    def test_empty_input(self):
        """Test empty input returns empty lists."""
        result = validate_extensions([], {})
        assert result == ([], [], [])

    def test_valid_extensions(self):
        """Test valid extension tokens."""
        mime_map = {"jpg": "image/jpeg", "png": "image/png"}
        cleaned, warnings, errors = validate_extensions(["jpg", "png"], mime_map)
        assert cleaned == ["jpg", "png"]
        assert errors == []

    def test_normalization(self):
        """Test that tokens are normalized."""
        mime_map = {"jpg": "image/jpeg"}
        cleaned, warnings, errors = validate_extensions([" .JPG ", ".jpg"], mime_map)
        assert cleaned == ["jpg"]  # deduplicated
        assert errors == []

    def test_invalid_tokens(self):
        """Test rejection of invalid tokens."""
        mime_map = {}
        cleaned, warnings, errors = validate_extensions(["*.jpg", "a/b"], mime_map)
        assert cleaned == []
        assert len(errors) == 1
        assert "Invalid --extensions" in errors[0]

    def test_unknown_extensions_warning(self):
        """Test warning for unknown extensions."""
        mime_map = {"jpg": "image/jpeg"}
        cleaned, warnings, errors = validate_extensions(["jpg", "xyz"], mime_map)
        assert cleaned == ["jpg", "xyz"]
        assert errors == []
        assert len(warnings) > 0
        assert "unknown extension(s)" in warnings[0].lower()

    def test_multi_segment_warning(self):
        """Test warning for multi-segment extensions."""
        mime_map = {"jpg": "image/jpeg"}
        cleaned, warnings, errors = validate_extensions(["tar.gz"], mime_map)
        assert cleaned == ["tar.gz"]
        assert errors == []
        # Should have warnings about multi-segment
        assert any("multi-segment" in w.lower() for w in warnings)


class TestLevenshtein:
    """Tests for _levenshtein function."""

    def test_identical_strings(self):
        """Test distance between identical strings."""
        assert _levenshtein("test", "test") == 0

    def test_empty_strings(self):
        """Test distance with empty strings."""
        assert _levenshtein("", "test") == 4
        assert _levenshtein("test", "") == 4
        assert _levenshtein("", "") == 0

    def test_single_character_diff(self):
        """Test single character difference."""
        assert _levenshtein("test", "tent") == 1
        assert _levenshtein("cat", "bat") == 1

    def test_multiple_differences(self):
        """Test multiple character differences."""
        assert _levenshtein("kitten", "sitting") == 3


class TestSuggestToken:
    """Tests for _suggest_token function."""

    def test_exact_match(self):
        """Test suggestion for exact match."""
        candidates = ["retain", "trash", "delete"]
        result = _suggest_token("retain", candidates)
        assert result == "retain"

    def test_close_match(self):
        """Test suggestion for close match."""
        candidates = ["retain", "trash", "delete"]
        result = _suggest_token("retian", candidates)  # 1 char difference
        assert result == "retain"

    def test_no_close_match(self):
        """Test no suggestion when distance > 2."""
        candidates = ["retain", "trash", "delete"]
        result = _suggest_token("xyz", candidates)
        assert result is None

    def test_case_insensitive(self):
        """Test case-insensitive matching."""
        candidates = ["retain", "trash", "delete"]
        result = _suggest_token("RETAIN", candidates)
        assert result == "retain"


class TestNormalizePolicyToken:
    """Tests for normalize_policy_token function."""

    def test_valid_token(self):
        """Test normalization of valid policy token."""
        aliases = {"retain": "retain", "trash": "trash", "delete": "delete"}
        normalized, warnings, errors, telemetry = normalize_policy_token(
            "retain", strict=True, aliases=aliases, default_value="retain"
        )
        assert normalized == "retain"
        assert warnings == []
        assert errors == []
        assert telemetry == {}

    def test_none_input(self):
        """Test None input uses default."""
        aliases = {"retain": "retain"}
        normalized, warnings, errors, telemetry = normalize_policy_token(
            None, strict=True, aliases=aliases, default_value="retain"
        )
        assert normalized == "retain"
        assert warnings == []
        assert errors == []

    def test_empty_string(self):
        """Test empty string uses default."""
        aliases = {"retain": "retain"}
        normalized, warnings, errors, telemetry = normalize_policy_token(
            "", strict=True, aliases=aliases, default_value="retain"
        )
        assert normalized == "retain"

    def test_unknown_strict_mode(self):
        """Test unknown token in strict mode returns error."""
        aliases = {"retain": "retain", "trash": "trash"}
        normalized, warnings, errors, telemetry = normalize_policy_token(
            "invalid", strict=True, aliases=aliases, default_value="retain"
        )
        assert normalized == "retain"
        assert len(errors) == 1
        assert "Unknown" in errors[0]
        assert "unknown_policy" in telemetry

    def test_unknown_non_strict_mode(self):
        """Test unknown token in non-strict mode returns warning."""
        aliases = {"retain": "retain", "trash": "trash"}
        normalized, warnings, errors, telemetry = normalize_policy_token(
            "invalid", strict=False, aliases=aliases, default_value="retain"
        )
        assert normalized == "retain"
        assert len(warnings) == 1
        assert "Falling back" in warnings[0]
        assert errors == []
        assert "unknown_policy" in telemetry

    def test_whitespace_normalization(self):
        """Test that whitespace/underscores/hyphens are normalized."""
        aliases = {"retain": "retain", "trash": "trash"}
        normalized, warnings, errors, telemetry = normalize_policy_token(
            "re-tain", strict=True, aliases=aliases, default_value="retain"
        )
        assert normalized == "retain"
