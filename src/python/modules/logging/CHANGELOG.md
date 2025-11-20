# python_logging_framework – Changelog

All notable changes to the **python_logging_framework** are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [0.1.0] - 2024-11-19
### Added
- Comprehensive module documentation (README.md, CHANGELOG.md)
- Package metadata and installation instructions

### Changed
- Updated documentation to reflect current functionality
- Enhanced README with usage examples and troubleshooting

## [0.1.0] - (Initial Release)
### Added
- Cross-platform structured logging framework
- Logging Specification compliance
- Multiple log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
- Dual output modes: plain text and JSON
- Automatic log file creation and management
- Timezone-aware timestamps (IST by default)
- Metadata validation against recommended keys
- Script name auto-detection
- PID and hostname tracking
- Automatic fallback to console if file operations fail

### Features
- **initialise_logger** - Framework initialization with configurable options
- **log_debug** - DEBUG level logging
- **log_info** - INFO level logging
- **log_warning** - WARNING level logging
- **log_error** - ERROR level logging
- **log_critical** - CRITICAL level logging
- **validate_metadata_keys** - Metadata validation helper

### Log Format
- **Plain Text:** `[YYYY-MM-DD HH:MM:SS.fff IST] [LEVEL] [SCRIPT] [HOSTNAME] [PID] Message [key=value ...]`
- **JSON:** Structured JSON with timestamp, level, script, host, pid, message, and metadata fields

### Metadata Support
- Recommended metadata keys: CorrelationId, User, TaskId, FileName, Duration
- Validation warnings for non-standard keys
- Automatic key-value formatting in plain text mode
- Nested metadata support in JSON mode

### Configuration
- Default log directory: `<script_root>/logs`
- Default log level: INFO
- Default format: Plain text
- Log file naming: `<script_name>_python_<YYYY-MM-DD>.log`
- IST timezone (Asia/Kolkata)

### Custom Formatters
- **SpecFormatter** - Plain text format conforming to specification
- **JSONFormatter** - Structured JSON format for log aggregation tools

### Cross-Platform
- Windows, Linux, macOS support
- Timezone detection (IST primary, fallback to UTC)
- Path normalization for cross-platform compatibility

### Dependencies
- Python 3.7+
- Standard library: logging, os, socket, sys, datetime, pathlib, json
- zoneinfo (Python 3.9+) for timezone support

### Package Info
- Installable via pip (`pip install -e .`)
- PYTHONPATH compatible
- egg-info metadata included

## [Unreleased]
### Planned
- Additional timezone support (configurable)
- Log rotation support (size-based, time-based)
- Async logging for high-throughput scenarios
- Custom formatter registration
- Log file compression
- Remote logging (syslog, HTTP endpoints)
- Performance metrics and statistics
- Structured exception logging
- Log level filtering per output target
- Color-coded console output
- Python 2.7 compatibility (if needed)
- Type hints (PEP 484)
- Dataclass metadata support (Python 3.7+)

---

For usage examples and detailed documentation, see [README.md](./README.md).
