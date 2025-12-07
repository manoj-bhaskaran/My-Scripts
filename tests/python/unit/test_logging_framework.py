"""
Unit tests for src/python/modules/logging/python_logging_framework.py

Tests logging framework core functions including logger initialization,
formatters, and logging helper functions.
"""

import pytest
import logging
import sys
import json
import tempfile
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo

# Add src path to allow imports
src_logging = Path(__file__).resolve().parents[3] / "src" / "python" / "modules" / "logging"
if str(src_logging) not in sys.path:
    sys.path.insert(0, str(src_logging))

from python_logging_framework import (
    SpecFormatter,
    JSONFormatter,
    initialise_logger,
    validate_metadata_keys,
    log_info,
    log_debug,
    log_warning,
    log_error,
    log_critical,
    RECOMMENDED_METADATA_KEYS,
)


# Helper function to get today's log file name
def get_log_file_path(tmp_path: Path, script_name: str) -> Path:
    """Get the expected log file path for a given script name."""
    IST = ZoneInfo("Asia/Kolkata")
    today = datetime.now(IST).strftime("%Y-%m-%d")
    return tmp_path / f"{script_name}_python_{today}.log"


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


class TestLoggerNameAndCustomDir:
    """Tests for logger initialization with custom parameters."""

    def test_initialise_logger_creates_logger(self):
        """Test logger initialization."""
        with tempfile.TemporaryDirectory() as tmpdir:
            logger = initialise_logger("test_module", log_dir=tmpdir)
            assert logger.name == "test_module"
            assert isinstance(logger, logging.Logger)

    def test_logger_uses_custom_log_dir(self, tmp_path):
        """Test custom log directory."""
        log_dir = tmp_path / "logs"
        logger = initialise_logger("test", log_dir=str(log_dir))

        # Log something
        log_info(logger, "Test message")

        # Verify log file created in custom dir
        assert log_dir.exists()
        log_files = list(log_dir.glob("*.log"))
        assert len(log_files) > 0

    def test_log_with_metadata(self, tmp_path):
        """Test logging with structured metadata."""
        logger = initialise_logger("test_with_metadata", log_dir=str(tmp_path))

        metadata = {"user_id": 123, "action": "delete"}
        log_info(logger, "User action", metadata=metadata)

        # Flush handlers to ensure logs are written
        for handler in logger.handlers:
            handler.flush()

        # Find the log file using helper function
        log_file = get_log_file_path(tmp_path, "test_with_metadata")

        assert log_file.exists()

        # Verify metadata in log file
        content = log_file.read_text()
        assert "user_id" in content
        assert "123" in content


class TestLoggingHelpers:
    """Tests for logging helper functions."""

    def test_log_debug(self, tmp_path):
        """Test debug level logging."""
        logger = initialise_logger("test_log_debug", log_dir=str(tmp_path), log_level=logging.DEBUG)
        log_debug(logger, "Debug message")

        # Flush handlers
        for handler in logger.handlers:
            handler.flush()

        log_file = get_log_file_path(tmp_path, "test_log_debug")
        assert log_file.exists()
        content = log_file.read_text()
        assert "Debug message" in content

    def test_log_info(self, tmp_path):
        """Test info level logging."""
        logger = initialise_logger("test_log_info", log_dir=str(tmp_path))
        log_info(logger, "Info message")

        # Flush handlers
        for handler in logger.handlers:
            handler.flush()

        log_file = get_log_file_path(tmp_path, "test_log_info")
        assert log_file.exists()
        content = log_file.read_text()
        assert "Info message" in content

    def test_log_warning(self, tmp_path):
        """Test warning level logging."""
        logger = initialise_logger("test_log_warning", log_dir=str(tmp_path))
        log_warning(logger, "Warning message")

        # Flush handlers
        for handler in logger.handlers:
            handler.flush()

        log_file = get_log_file_path(tmp_path, "test_log_warning")
        assert log_file.exists()
        content = log_file.read_text()
        assert "Warning message" in content

    def test_log_error(self, tmp_path):
        """Test error level logging."""
        logger = initialise_logger("test_log_error", log_dir=str(tmp_path))
        log_error(logger, "Error message")

        # Flush handlers
        for handler in logger.handlers:
            handler.flush()

        log_file = get_log_file_path(tmp_path, "test_log_error")
        assert log_file.exists()
        content = log_file.read_text()
        assert "Error message" in content

    def test_log_critical(self, tmp_path):
        """Test critical level logging."""
        logger = initialise_logger("test_log_critical", log_dir=str(tmp_path))
        log_critical(logger, "Critical message")

        # Flush handlers
        for handler in logger.handlers:
            handler.flush()

        log_file = get_log_file_path(tmp_path, "test_log_critical")
        assert log_file.exists()
        content = log_file.read_text()
        assert "Critical message" in content
