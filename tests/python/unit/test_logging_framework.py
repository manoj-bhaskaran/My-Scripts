"""
Unit tests for src/common/python_logging_framework.py

Tests logging framework core functions including logger initialization,
formatters, and logging helper functions.
"""

import pytest
import logging
import sys
import json
import tempfile
from pathlib import Path

# Add src path to allow imports
src_common = Path(__file__).resolve().parents[3] / "src" / "common"
if str(src_common) not in sys.path:
    sys.path.insert(0, str(src_common))

from python_logging_framework import (
    SpecFormatter,
    JSONFormatter,
    initialise_logger,
    validate_metadata_keys,
    RECOMMENDED_METADATA_KEYS,
)


class TestSpecFormatter:
    """Tests for SpecFormatter class."""

    def test_formatter_exists(self):
        """Test that SpecFormatter class exists and can be instantiated."""
        formatter = SpecFormatter()
        assert formatter is not None
        assert isinstance(formatter, logging.Formatter)

    def test_format_creates_string(self):
        """Test that format method returns a string."""
        formatter = SpecFormatter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="Test message",
            args=(),
            exc_info=None,
        )
        record.script_name = "test_script"
        result = formatter.format(record)
        assert isinstance(result, str)
        assert len(result) > 0


class TestJSONFormatter:
    """Tests for JSONFormatter class."""

    def test_formatter_exists(self):
        """Test that JSONFormatter class exists and can be instantiated."""
        formatter = JSONFormatter()
        assert formatter is not None
        assert isinstance(formatter, logging.Formatter)

    def test_format_returns_valid_json(self):
        """Test that format method returns valid JSON."""
        formatter = JSONFormatter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="Test message",
            args=(),
            exc_info=None,
        )
        record.script_name = "test_script"
        result = formatter.format(record)

        # Should be valid JSON
        parsed = json.loads(result)
        assert isinstance(parsed, dict)
        assert "level" in parsed
        assert "message" in parsed


class TestInitialiseLogger:
    """Tests for initialise_logger function."""

    def test_logger_creation(self):
        """Test that initialise_logger creates a logger."""
        with tempfile.TemporaryDirectory() as tmpdir:
            logger = initialise_logger(
                script_name="test_script.py",
                log_dir=tmpdir,
            )
            assert logger is not None
            assert isinstance(logger, logging.Logger)

    def test_logger_has_handlers(self):
        """Test that logger has at least one handler."""
        with tempfile.TemporaryDirectory() as tmpdir:
            logger = initialise_logger(
                script_name="test_script.py",
                log_dir=tmpdir,
            )
            assert len(logger.handlers) > 0

    def test_logger_level_can_be_set(self):
        """Test that logger level can be configured."""
        with tempfile.TemporaryDirectory() as tmpdir:
            logger = initialise_logger(
                script_name="test_script.py",
                log_dir=tmpdir,
                log_level=logging.DEBUG,
            )
            assert logger.level == logging.DEBUG


class TestValidateMetadataKeys:
    """Tests for validate_metadata_keys function."""

    def test_function_exists(self):
        """Test that validate_metadata_keys function exists."""
        assert callable(validate_metadata_keys)

    def test_valid_keys_no_error(self):
        """Test that valid keys don't raise errors."""
        metadata = {"CorrelationId": "123"}
        # Should not raise exception
        validate_metadata_keys(metadata)

    def test_empty_metadata(self):
        """Test that empty metadata doesn't raise errors."""
        metadata = {}
        # Should not raise exception
        validate_metadata_keys(metadata)


class TestRecommendedMetadataKeys:
    """Tests for RECOMMENDED_METADATA_KEYS constant."""

    def test_recommended_keys_exist(self):
        """Test that recommended metadata keys are defined."""
        assert RECOMMENDED_METADATA_KEYS is not None
        assert isinstance(RECOMMENDED_METADATA_KEYS, set)

    def test_recommended_keys_contain_expected_values(self):
        """Test that recommended keys include common metadata."""
        assert "CorrelationId" in RECOMMENDED_METADATA_KEYS
        assert "User" in RECOMMENDED_METADATA_KEYS
