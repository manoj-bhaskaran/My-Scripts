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

from __future__ import annotations

import logging  # Standard library logging
from logging import (
    Logger,
    LogRecord,
    Formatter,
    FileHandler,
    StreamHandler,
    INFO,
    DEBUG,
)  # type: ignore[attr-defined]
import os
import socket
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any
from zoneinfo import ZoneInfo
import json

# Constants
IST = ZoneInfo("Asia/Kolkata")
RECOMMENDED_METADATA_KEYS = {"CorrelationId", "User", "TaskId", "FileName", "Duration"}


class SpecFormatter(Formatter):  # type: ignore[misc]
    """
    Custom formatter for plain-text log messages according to the logging specification.
    """

    def format(self, record: LogRecord) -> str:
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


class JSONFormatter(Formatter):  # type: ignore[misc]
    """
    Custom formatter that outputs structured log records in JSON format.
    """

    def format(self, record: LogRecord) -> str:
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


def _resolve_default_log_path(script_name: str, log_dir: str | Path | None) -> Path:
    """Return the legacy auto-named log path for a script."""
    base_name = os.path.splitext(script_name)[0]
    today = datetime.now(IST).strftime("%Y-%m-%d")
    log_file_name = f"{base_name}_python_{today}.log"

    try:
        script_path = Path(script_name).resolve()
        root_dir = script_path.parents[1]
    except Exception:
        root_dir = Path.cwd()

    log_dir_path: Path = Path(log_dir) if log_dir else root_dir / "logs"
    return log_dir_path / log_file_name


def _resolve_log_path(
    script_name: str,
    log_dir: str | Path | None,
    log_file_path: str | Path | None,
    create_default_file: bool,
) -> Path | None:
    """Return the requested log path, if file logging should be enabled."""
    if log_file_path:
        return Path(log_file_path)
    if create_default_file:
        return _resolve_default_log_path(script_name, log_dir)
    return None


def _create_file_handler(
    file_path: Path | None,
    file_level: int,
    formatter: Formatter,
) -> FileHandler | None:
    """Create a file handler, falling back to console-only logging on failure."""
    if file_path is None:
        return None

    try:
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_handler = FileHandler(file_path, encoding="utf-8")
        file_handler.setLevel(file_level)
        file_handler.setFormatter(formatter)
        return file_handler
    except Exception as e:
        print(f"[WARNING] Failed to initialise file logging: {e}", file=sys.stderr)
        return None


def _create_console_handler(console_level: int, formatter: Formatter) -> StreamHandler:
    """Create a configured console handler."""
    console_handler = StreamHandler(sys.stdout)
    console_handler.setLevel(console_level)
    console_handler.setFormatter(formatter)
    return console_handler


def _configure_child_logger_for_root(
    script_name: str, log_level: int, root_had_handlers: bool
) -> Logger:
    """Return a child logger that propagates to root without weakening existing root filters."""
    logger = logging.getLogger(script_name)
    logger.setLevel(logging.NOTSET if root_had_handlers else log_level)
    logger.propagate = True
    logger.script_name = script_name
    return logger


def initialise_logger(
    script_name: str | None = None,
    log_dir: str | Path | None = None,
    log_level: int = INFO,
    json_format: bool = False,
    propagate: bool = False,
    console_level: int | None = None,
    log_file_path: str | Path | None = None,
    file_level: int = DEBUG,
    create_default_file: bool = True,
    configure_root: bool = False,
) -> Logger:
    """
    Initialise and configure a logger instance.

    Args:
        script_name (str | None): Name of the script using the logger.
        log_dir (str | Path | None): Directory to store log files. Defaults to <root>/logs.
        log_level (int): Logger level (e.g., logging.INFO).
        json_format (bool): If True, use JSONFormatter; otherwise use plain text.
        propagate (bool): If False, prevent propagation to the root logger.
        console_level (int | None): Console handler level. Defaults to ``log_level``.
        log_file_path (str | Path | None): Exact file path for file logging.
            Parent directories are created automatically.
        file_level (int): File handler level when a file handler is configured.
        create_default_file (bool): If True and ``log_file_path`` is not provided,
            create the legacy auto-named log file under ``log_dir``.
        configure_root (bool): If True, attach handlers to the root logger and
            return the named logger so sibling modules using ``getLogger(__name__)``
            propagate through the shared handlers. If the root logger already has
            handlers, its existing level and handler set are preserved.

    Returns:
        Logger: Configured logger instance.
    """
    script_name = script_name or os.path.basename(sys.argv[0])
    handler_console_level = log_level if console_level is None else console_level
    formatter = JSONFormatter() if json_format else SpecFormatter()
    target_logger = logging.getLogger() if configure_root else logging.getLogger(script_name)
    root_had_handlers = bool(target_logger.handlers) if configure_root else False

    if target_logger.handlers:
        if not configure_root:
            target_logger.setLevel(log_level)
    else:
        file_path = _resolve_log_path(script_name, log_dir, log_file_path, create_default_file)
        file_handler = _create_file_handler(file_path, file_level, formatter)
        console_handler = _create_console_handler(handler_console_level, formatter)
        target_level = min(log_level, handler_console_level, file_level)
        target_logger.setLevel(target_level if configure_root else log_level)
        target_logger.addHandler(console_handler)
        if file_handler:
            target_logger.addHandler(file_handler)

    target_logger.propagate = False if configure_root else propagate
    target_logger.script_name = script_name

    if configure_root:
        return _configure_child_logger_for_root(script_name, log_level, root_had_handlers)

    return target_logger


def validate_metadata_keys(metadata: Dict[str, Any]) -> None:
    """
    Validate metadata keys against the recommended specification keys.

    Args:
        metadata (Dict[str, Any]): Dictionary of metadata key-value pairs.

    Prints a warning if non-standard keys are detected.
    """
    invalid_keys = set(metadata) - RECOMMENDED_METADATA_KEYS
    if invalid_keys:
        print(f"[WARNING] Non-standard metadata keys: {invalid_keys}", file=sys.stderr)


def log_debug(logger: Logger, message: str, metadata: Optional[Dict[str, Any]] = None) -> None:
    """Log a DEBUG level message with optional metadata."""
    logger.debug(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )


def log_info(logger: Logger, message: str, metadata: Optional[Dict[str, Any]] = None) -> None:
    """Log an INFO level message with optional metadata."""
    logger.info(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )


def log_warning(logger: Logger, message: str, metadata: Optional[Dict[str, Any]] = None) -> None:
    """Log a WARNING level message with optional metadata."""
    logger.warning(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )


def log_error(logger: Logger, message: str, metadata: Optional[Dict[str, Any]] = None) -> None:
    """Log an ERROR level message with optional metadata."""
    logger.error(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )


def log_critical(logger: Logger, message: str, metadata: Optional[Dict[str, Any]] = None) -> None:
    """Log a CRITICAL level message with optional metadata."""
    logger.critical(
        message, extra={"extra_metadata": metadata or {}, "script_name": logger.script_name}
    )
