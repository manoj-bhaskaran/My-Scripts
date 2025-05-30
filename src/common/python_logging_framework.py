# File: src/common/python_logging_framework.py

import logging
import os
import socket
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict
import pytz

# Constants
IST = pytz.timezone("Asia/Kolkata")

# Custom Formatter
class SpecFormatter(logging.Formatter):
    def format(self, record):
        # Timestamp in IST with milliseconds
        dt = datetime.fromtimestamp(record.created, IST)
        timestamp = dt.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]  # millisecond precision
        tzname = dt.strftime('%Z')

        script_name = record.__dict__.get("script_name", os.path.basename(sys.argv[0]))
        hostname = socket.gethostname()
        pid = os.getpid()
        level = record.levelname
        msg = record.getMessage()
        extra_metadata = record.__dict__.get("extra_metadata", {})

        metadata_str = " ".join(f"{k}={v}" for k, v in extra_metadata.items()) if extra_metadata else ""

        return f"[{timestamp} {tzname}] [{level}] [{script_name}] [{hostname}] [{pid}] {msg}" + (f" [{metadata_str}]" if metadata_str else "")


# Logger Initialisation
def initialise_logger(script_name: Optional[str] = None,
                      log_dir: Optional[str] = None,
                      log_level: int = logging.INFO) -> logging.Logger:
    if not script_name:
        script_name = os.path.basename(sys.argv[0])

    base_name = os.path.splitext(script_name)[0]
    today = datetime.now(IST).strftime("%Y-%m-%d")
    log_file_name = f"{base_name}_python_{today}.log"

    if not log_dir:
        root_dir = Path(script_name).resolve().parent.parent
        log_dir = root_dir / "logs"
    else:
        log_dir = Path(log_dir)

    try:
        log_dir.mkdir(parents=True, exist_ok=True)
        file_path = log_dir / log_file_name
        file_handler = logging.FileHandler(file_path, encoding='utf-8')
    except Exception:
        file_handler = None

    console_handler = logging.StreamHandler(sys.stdout)

    formatter = SpecFormatter()
    console_handler.setFormatter(formatter)
    if file_handler:
        file_handler.setFormatter(formatter)

    logger = logging.getLogger(script_name)
    logger.setLevel(log_level)
    logger.propagate = False

    if not logger.handlers:
        logger.addHandler(console_handler)
        if file_handler:
            logger.addHandler(file_handler)

    return logger


# Logging functions with metadata support
def log_debug(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    logger.debug(message, extra={"extra_metadata": metadata or {}})

def log_info(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    logger.info(message, extra={"extra_metadata": metadata or {}})

def log_warning(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    logger.warning(message, extra={"extra_metadata": metadata or {}})

def log_error(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    logger.error(message, extra={"extra_metadata": metadata or {}})

def log_critical(logger: logging.Logger, message: str, metadata: Optional[Dict] = None):
    logger.critical(message, extra={"extra_metadata": metadata or {}})
