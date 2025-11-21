"""
python_logging_framework.py

A reusable Python logging framework module compliant with the Cross-Platform Logging Specification.

This module provides structured and plain-text logging support with consistent formatting,
support for optional metadata, fallback mechanisms, and configurable log output.

Key Features:
- Millisecond-precision timestamps in IST
- Support for both plain text and JSON log formats
- Script-level log identification
- Console and file handlers with fallback
- Optional metadata validation
- Configurable log level, output directory, and propagation

"""

import logging
import os
import socket
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict
from zoneinfo import ZoneInfo
import json

# Constants
IST = ZoneInfo("Asia/Kolkata")
RECOMMENDED_METADATA_KEYS = {"CorrelationId", "User", "TaskId", "FileName", "Duration"}


class SpecFormatter(logging.Formatter):
    """
    Custom formatter for plain-text log messages according to the logging specification.
    """

    def format(self, record):
        """
        Format the log record as a plain-text string with timestamp, level, script, host, PID, message, and metadata.
        """
        dt = datetime.fromtimestamp(record.created, IST)
        timestamp = dt.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        tzname = dt.strftime("%Z")
        script_name = getattr(
            record, "script_name", getattr(record, "name", os.path.basename(sys.argv[0]))
        )
        hostname = socket.gethostname()
        pid = os.getpid()
        level = record.levelname
        msg = record.getMessage()
        metadata = record.__dict__.get("extra_metadata", {})
        metadata_str = " ".join(f"{k}={v}" for k, v in metadata.items()) if metadata else ""
        return f"[{timestamp} {tzname}] [{level}] [{script_name}] [{hostname}] [{pid}] {msg}" + (
            f" [{metadata_str}]" if metadata_str else ""
        )


class JSONFormatter(logging.Formatter):
    """
    Custom formatter that outputs structured log records in JSON format.
    """

    def format(self, record):
        """
        Format the log record as a JSON object with timestamp, level, script, host, PID, message, and metadata.
        """
        dt = datetime.fromtimestamp(record.created, IST)
        timestamp = dt.isoformat(timespec="milliseconds")
        log_record = {
            "timestamp": f"{timestamp}+05:30",
            "level": record.levelname,
            "script": getattr(
                record, "script_name", getattr(record, "name", os.path.basename(sys.argv[0]))
            ),
            "host": socket.gethostname(),
            "pid": os.getpid(),
            "message": record.getMessage(),
            "metadata": record.__dict__.get("extra_metadata", {}),
        }
        return json.dumps(log_record, ensure_ascii=False)


def initialise_logger(
    script_name: Optional[str] = None,
    log_dir: Optional[str] = None,
    log_level: int = logging.INFO,
    json_format: bool = False,
    propagate: bool = False,
) -> logging.Logger:
    """
    Initialise and configure a logger instance.

    Args:
        script_name (Optional[str]): Name of the script using the logger.
        log_dir (Optional[str]): Directory to store log files. Defaults to <root>/logs.
        log_level (int): Logging level (e.g., logging.INFO).
        json_format (bool): If True, use JSONFormatter; otherwise use plain text.
        propagate (bool): If False, prevent propagation to the root logger.

    Returns:
        logging.Logger: Configured logger instance.
    """
    if not script_name:
        script_name = os.path.basename(sys.argv[0])

    base_name = os.path.splitext(script_name)[0]
    today = datetime.now(IST).strftime("%Y-%m-%d")
    log_file_name = f"{base_name}_python_{today}.log"

    try:
        script_path = Path(script_name).resolve()
        root_dir = script_path.parents[1]
    except Exception:
        root_dir = Path.cwd()

    log_dir = Path(log_dir) if log_dir else root_dir / "logs"

    try:
        log_dir.mkdir(parents=True, exist_ok=True)
        file_path = log_dir / log_file_name
        file_handler = logging.FileHandler(file_path, encoding="utf-8")
    except Exception as e:
        print(f"[WARNING] Failed to initialise file logging: {e}", file=sys.stderr)
        file_handler = None

    console_handler = logging.StreamHandler(sys.stdout)
    formatter = JSONFormatter() if json_format else SpecFormatter()
    console_handler.setFormatter(formatter)
    if file_handler:
        file_handler.setFormatter(formatter)

    logger = logging.getLogger(script_name)
    logger.setLevel(log_level)
    logger.propagate = propagate
    logger.script_name = script_name

    if not logger.handlers:
        logger.addHandler(console_handler)
        if file_handler:
            logger.addHandler(file_handler)

    return logger


def validate_metadata_keys(metadata: Dict):
    """
    Validate metadata keys against the recommended specification keys.

    Args:
        metadata (Dict): Dictionary of metadata key-value pairs.

    Prints a warning if non-standard keys are detected.
    """
    invalid_keys = set(metadata) - RECOMMENDED_METADATA_KEYS
    if invalid_keys:
        print(f"[WARNING] Non-standard metadata keys: {invalid_keys}", file=sys.stderr)


def log_debug(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    """Log a DEBUG level message with optional metadata."""
    logger.debug(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )


def log_info(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    """Log an INFO level message with optional metadata."""
    logger.info(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )


def log_warning(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    """Log a WARNING level message with optional metadata."""
    logger.warning(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )


def log_error(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    """Log an ERROR level message with optional metadata."""
    logger.error(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )


def log_critical(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    """Log a CRITICAL level message with optional metadata."""
    logger.critical(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )
