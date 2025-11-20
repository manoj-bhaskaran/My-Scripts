# PurgeLogs Module – Changelog

All notable changes to the **PurgeLogs module** are documented here.
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
- Log file purging with multiple cleanup strategies
- Four mutually exclusive cleanup modes:
  - RetentionDays: Age-based cleanup (remove entries older than N days)
  - MaxSizeMB: Size-based trimming (keep most recent entries within size limit)
  - TruncateIfLarger: Conditional truncation (clear if exceeds threshold)
  - TruncateLog: Unconditional truncation
- Timestamp parsing for standardized log format
- Dry-run mode for safe testing
- WhatIf support (PowerShell best practices)
- Verbose output for debugging
- ConvertTo-Bytes helper for human-readable size conversion
- Integration with PowerShellLoggingFramework

### Features
- **Clear-LogFile** - Primary log purging function
- **ConvertTo-Bytes** - Size string to bytes conversion
- **Strategy precedence:** RetentionDays > MaxSizeMB > TruncateIfLarger > TruncateLog
- **Timestamp format support:** `[YYYY-MM-DD HH:MM:SS.fff TIMEZONE]`
- **Size units:** KB, MB, GB, TB (case-insensitive)

### Timestamp Parsing
- Supports multiple timestamp variations
- Handles logs with/without milliseconds
- Handles logs with/without timezone
- Safe fallback for non-parseable lines

### Cleanup Strategies
1. **RetentionDays:**
   - Parses log timestamps
   - Removes entries older than threshold
   - Keeps entries within retention period

2. **MaxSizeMB:**
   - Reads log in reverse order
   - Accumulates most recent entries
   - Trims to fit within size limit

3. **TruncateIfLarger:**
   - Checks current file size
   - Clears file if exceeds threshold
   - No action if within limit

4. **TruncateLog:**
   - Unconditional file clearing
   - Use with caution

### Integration
- Uses PowerShellLoggingFramework for module logging
- Compatible with PowerShellLoggingFramework log format
- Task Scheduler integration examples

## [Unreleased]
### Planned
- Automatic backup before purge
- Compression of archived logs
- Multiple file processing in single call
- Regex-based log line filtering
- Custom timestamp format support
- Statistics reporting (entries removed, space freed)
- Email notifications on cleanup
- Configuration file support
- Archive old logs instead of delete
- Parallel processing for large files
- Incremental cleanup mode

---

For usage examples and detailed documentation, see [README.md](./README.md).
