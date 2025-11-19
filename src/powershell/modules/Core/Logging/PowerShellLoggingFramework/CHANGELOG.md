# PowerShell Logging Framework – Changelog

All notable changes to the **PowerShell Logging Framework** are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [2.0.0] - 2024-11-19
### Added
- Comprehensive module documentation (README.md, CHANGELOG.md)
- Module manifest (.psd1) with metadata, tags, and version tracking
- Initial versioned release tracking

### Changed
- Updated documentation to reflect current functionality

## [1.0.0] - (Prior Release)
### Added
- Cross-platform structured logging framework
- Multiple log levels: DEBUG (10), INFO (20), WARNING (30), ERROR (40), CRITICAL (50)
- Dual output modes: plain text and JSON
- Automatic log file creation and management
- Timezone-aware timestamps with abbreviation support
- Metadata validation against recommended keys
- Global configuration via `$Global:LogConfig`
- Automatic fallback to console if file operations fail
- Script name auto-detection from caller context

### Features
- **Initialize-Logger** - Framework initialization with configurable options
- **Write-LogDebug** - DEBUG level logging
- **Write-LogInfo** - INFO level logging
- **Write-LogWarning** - WARNING level logging
- **Write-LogError** - ERROR level logging
- **Write-LogCritical** - CRITICAL level logging

### Log Format
- **Plain Text:** `[YYYY-MM-DD HH:MM:SS.fff TIMEZONE] [LEVEL] [SCRIPT] [HOST] [PID] Message [Key=Value ...]`
- **JSON:** Structured JSON with timestamp, level, script, host, pid, message, and metadata fields

### Metadata Support
- Recommended metadata keys: CorrelationId, User, TaskId, FileName, Duration
- Validation warnings for non-standard keys
- Automatic key-value formatting in plain text mode
- Nested metadata support in JSON mode

### Configuration
- Default log directory: `<script_root>/logs`
- Default log level: 20 (INFO)
- Default format: Plain text
- Log file naming: `<script_name>_powershell_<YYYY-MM-DD>.log`

### Cross-Platform
- Windows, Linux, macOS support
- System timezone detection and abbreviation
- Path normalization for cross-platform compatibility

## [Unreleased]
### Planned
- Log rotation support (size-based, time-based)
- Async logging for high-throughput scenarios
- Custom formatter support
- Log file compression
- Remote logging (syslog, HTTP endpoints)
- Performance metrics and statistics
- Structured exception logging
- Log level filtering per output target
- Color-coded console output
- Integration with Windows Event Log

---

For usage examples and detailed documentation, see [README.md](./README.md).
