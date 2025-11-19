# Python Logging Framework

## Overview
Cross-platform structured logging framework implementing the [Logging Specification](../../../../docs/specifications/logging_specification.md) for consistent log output across Python scripts.

## Version
Current version: **0.1.0**

## Installation

**Using pip (editable mode for development):**
```bash
pip install -e src/python/modules/logging
```

**Using pip (regular install):**
```bash
pip install src/python/modules/logging
```

**Direct import (if in PYTHONPATH):**
```python
import python_logging_framework as plog
```

## Features

- **Structured log format** matching PowerShell logging framework
- **Multiple log levels:** DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Dual output:** File and console with automatic fallback
- **Format options:** Plain text or JSON structured logging
- **Cross-platform:** Windows, Linux, macOS
- **Timezone-aware:** IST timezone support with automatic detection
- **Metadata validation:** Recommended keys for structured logging
- **Automatic log file naming:** `<script_name>_python_<YYYY-MM-DD>.log`
- **PID and hostname tracking:** Full context in every log entry

## Dependencies

- **Python 3.7+**
- **Standard library modules:**
  - logging
  - os
  - socket
  - sys
  - datetime
  - pathlib
  - json
- **zoneinfo** (Python 3.9+) for timezone support

## Functions

### initialise_logger

Initializes the logging framework for a Python script.

**Signature:**
```python
def initialise_logger(
    script_name: Optional[str] = None,
    log_dir: Optional[str] = None,
    log_level: int = logging.INFO,
    json_format: bool = False,
    propagate: bool = False
) -> logging.Logger
```

**Parameters:**

- **script_name** (str, optional)
  - Script name used in log entries and file naming
  - Default: `os.path.basename(sys.argv[0])`
  - Example: `"my_script.py"`

- **log_dir** (str, optional)
  - Directory where log files will be created
  - Default: `<script_root>/logs`
  - Created automatically if it doesn't exist

- **log_level** (int, optional)
  - Minimum log level to output
  - Values: `logging.DEBUG`, `logging.INFO`, `logging.WARNING`, `logging.ERROR`, `logging.CRITICAL`
  - Default: `logging.INFO`

- **json_format** (bool, optional)
  - Enable JSON structured logging
  - Default: `False` (plain text format)

- **propagate** (bool, optional)
  - Propagate logs to root logger
  - Default: `False`

**Returns:**
- `logging.Logger` instance configured for structured logging

**Examples:**

```python
import logging
import python_logging_framework as plog

# Basic initialization (auto-detect script name, INFO level)
logger = plog.initialise_logger()

# Specify log directory and script name
logger = plog.initialise_logger(
    script_name="my_script.py",
    log_dir="/var/log/myapp"
)

# Set DEBUG level for verbose logging
logger = plog.initialise_logger(log_level=logging.DEBUG)

# Enable JSON output
logger = plog.initialise_logger(json_format=True)

# Complete custom configuration
logger = plog.initialise_logger(
    script_name="backup_job.py",
    log_dir="/var/log/backups",
    log_level=logging.INFO,
    json_format=False,
    propagate=False
)
```

### log_debug

Writes a DEBUG level log entry.

**Signature:**
```python
def log_debug(logger: logging.Logger, message: str, metadata: Optional[Dict] = None)
```

**Examples:**

```python
plog.log_debug(logger, "Starting database connection")

plog.log_debug(logger, "Query parameters", metadata={
    "query": "SELECT * FROM users",
    "timeout": 30
})
```

### log_info

Writes an INFO level log entry.

**Signature:**
```python
def log_info(logger: logging.Logger, message: str, metadata: Optional[Dict] = None)
```

**Examples:**

```python
plog.log_info(logger, "Backup completed successfully")

plog.log_info(logger, "Files processed", metadata={
    "count": 150,
    "duration": 332.5
})
```

### log_warning

Writes a WARNING level log entry.

**Signature:**
```python
def log_warning(logger: logging.Logger, message: str, metadata: Optional[Dict] = None)
```

**Examples:**

```python
plog.log_warning(logger, "Disk space running low")

plog.log_warning(logger, "Retry attempt", metadata={
    "attempt": 2,
    "max_attempts": 5
})
```

### log_error

Writes an ERROR level log entry.

**Signature:**
```python
def log_error(logger: logging.Logger, message: str, metadata: Optional[Dict] = None)
```

**Examples:**

```python
plog.log_error(logger, "Database connection failed")

plog.log_error(logger, "Backup failed", metadata={
    "database": "mydb",
    "error": str(e)
})
```

### log_critical

Writes a CRITICAL level log entry.

**Signature:**
```python
def log_critical(logger: logging.Logger, message: str, metadata: Optional[Dict] = None)
```

**Examples:**

```python
plog.log_critical(logger, "System failure - shutting down")

plog.log_critical(logger, "Data corruption detected", metadata={
    "table": "transactions",
    "records_affected": 1500
})
```

### validate_metadata_keys

Validates metadata keys against recommended standards.

**Signature:**
```python
def validate_metadata_keys(metadata: Dict)
```

**Recommended keys:**
- `CorrelationId`
- `User`
- `TaskId`
- `FileName`
- `Duration`

Non-recommended keys trigger a warning but are still logged.

## Log Format

### Plain Text Format

```
[YYYY-MM-DD HH:MM:SS.fff IST] [LEVEL] [SCRIPT] [HOSTNAME] [PID] Message [Key=Value ...]
```

**Example:**
```
[2025-11-19 14:30:22.123 IST] [INFO] [backup_job.py] [server01] [12345] Backup started [database=mydb duration=120]
```

### JSON Format

```json
{
  "timestamp": "2025-11-19T14:30:22.123+05:30",
  "level": "INFO",
  "script": "backup_job.py",
  "host": "server01",
  "pid": 12345,
  "message": "Backup started",
  "metadata": {
    "database": "mydb",
    "duration": 120
  }
}
```

## Usage Examples

### Basic Script Logging

```python
#!/usr/bin/env python3
import logging
import python_logging_framework as plog

# Initialize logger
logger = plog.initialise_logger(
    script_name="my_backup.py",
    log_level=logging.INFO
)

# Log messages
plog.log_info(logger, "Backup process started")

try:
    # Your code here
    plog.log_info(logger, "Processing files", metadata={"count": 100})
except Exception as e:
    plog.log_error(logger, "Backup failed", metadata={
        "error": str(e)
    })
    exit(1)

plog.log_info(logger, "Backup completed successfully")
```

### Advanced Logging with Correlation

```python
import logging
import uuid
import python_logging_framework as plog

logger = plog.initialise_logger(
    log_dir="/var/log/myapp",
    log_level=logging.DEBUG
)

correlation_id = str(uuid.uuid4())

plog.log_info(logger, "Job started", metadata={
    "CorrelationId": correlation_id,
    "User": os.getenv("USER")
})

for file in files:
    plog.log_debug(logger, "Processing file", metadata={
        "FileName": file.name,
        "CorrelationId": correlation_id
    })

    # Process file...

    plog.log_info(logger, "File completed", metadata={
        "FileName": file.name,
        "Duration": 12.5,
        "CorrelationId": correlation_id
    })

plog.log_info(logger, "Job completed", metadata={
    "CorrelationId": correlation_id,
    "TotalFiles": len(files)
})
```

### JSON Logging for Log Aggregation

```python
import logging
import python_logging_framework as plog

# Perfect for shipping to ELK, Splunk, etc.
logger = plog.initialise_logger(
    script_name="api_service.py",
    json_format=True
)

plog.log_info(logger, "Application event", metadata={
    "event_type": "user_login",
    "user": "john.doe",
    "CorrelationId": "xyz789"
})
```

### Google Drive Integration Example

```python
import logging
import python_logging_framework as plog

logger = plog.initialise_logger(
    script_name="drive_space_monitor.py",
    log_level=logging.INFO
)

try:
    # Get storage quota
    about = service.about().get(fields="storageQuota").execute()
    quota = about.get('storageQuota', {})

    plog.log_debug(logger, f"Storage quota data: {quota}")

    # Check usage
    usage_percent = (int(quota['usage']) / int(quota['limit'])) * 100

    if usage_percent > 90:
        plog.log_warning(logger, "Storage almost full", metadata={
            "usage_percent": usage_percent,
            "limit_gb": int(quota['limit']) / (1024**3)
        })
    else:
        plog.log_info(logger, "Storage check completed", metadata={
            "usage_percent": usage_percent
        })

except Exception as e:
    plog.log_error(logger, f"Storage check failed: {e}")
```

## Configuration

### Timezone Support

The framework uses IST (Indian Standard Time) by default. Timestamps are formatted with timezone awareness:

```python
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")  # UTC+5:30
```

### Recommended Metadata Keys

```python
RECOMMENDED_METADATA_KEYS = {
    "CorrelationId",
    "User",
    "TaskId",
    "FileName",
    "Duration"
}
```

### Log File Location

Default: `<script_root>/logs/<script_name>_python_<YYYY-MM-DD>.log`

Example: `/app/scripts/logs/backup_job_python_2025-11-19.log`

## Custom Formatters

### SpecFormatter (Plain Text)

```python
class SpecFormatter(logging.Formatter):
    """Formats logs per cross-platform specification"""
    # Timestamp with milliseconds and timezone
    # Host, PID, script name
    # Metadata as key-value pairs
```

### JSONFormatter (Structured JSON)

```python
class JSONFormatter(logging.Formatter):
    """Formats logs as structured JSON"""
    # ISO 8601 timestamp
    # Nested metadata object
    # Machine-readable format
```

## Integration with PowerShell Logging

This framework produces logs compatible with the PowerShellLoggingFramework:

**Python:**
```
[2025-11-19 14:30:22.123 IST] [INFO] [backup.py] [server01] [12345] Backup started
```

**PowerShell:**
```
[2025-11-19 14:30:22.123 IST] [INFO] [backup.ps1] [server01] [67890] Backup started
```

Both frameworks follow the same [Logging Specification](../../../../docs/specifications/logging_specification.md).

## Package Metadata

- **Name:** python_logging_framework
- **Version:** 0.1.0
- **Author:** Manoj Bhaskaran
- **Summary:** Cross-platform logging framework for Python, PowerShell, and Batch script integrations
- **Requires-Python:** >=3.7
- **License:** MIT

## Used By

- `src/python/cloud/drive_space_monitor.py` - Google Drive storage monitoring
- `src/python/cloud/cloudconvert_utils.py` - Cloud conversion utilities
- Various Python scripts across the repository

## Logging Specification Compliance

This module implements the [Cross-Platform Logging Specification](../../../../docs/specifications/logging_specification.md) which ensures:

- Consistent log format across Python and PowerShell
- Standard timestamp format with timezone
- Structured metadata support
- Log level standardization
- Cross-platform compatibility

## Troubleshooting

### "Module not found"
```bash
# Install in editable mode
pip install -e src/python/modules/logging

# Or add to PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:$(pwd)/src/python/modules/logging"
```

### "Log file not created"
- Check log directory exists and is writable
- Verify `initialise_logger` was called
- Check console output for fallback messages

### "Timezone error (Python < 3.9)"
- zoneinfo requires Python 3.9+
- For older versions, the framework falls back to UTC
- Consider upgrading to Python 3.9+

### "Metadata validation warnings"
- Use recommended metadata keys: CorrelationId, User, TaskId, FileName, Duration
- Warnings don't prevent logging, just indicate non-standard keys

### "JSON format not working"
- Ensure `json_format=True` is passed to `initialise_logger`
- Check log file for proper JSON structure
- Verify no syntax errors in metadata dictionaries

## Performance Considerations

- File writes use Python's logging buffered I/O
- Automatic fallback to console if file operations fail
- Minimal overhead for disabled log levels
- JSON serialization adds minimal latency (~microseconds)
- Metadata validation is fast (set membership test)

## Testing

```python
# Run tests
pytest tests/python/unit/test_logging_framework.py

# With coverage
pytest --cov=python_logging_framework tests/python/unit/test_logging_framework.py
```

## License

MIT License

---

For module history, see [CHANGELOG.md](./CHANGELOG.md).
