# PurgeLogs Module – Changelog

All notable changes to the **PurgeLogs module** are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [2.2.1] - 2026-03-27
### Fixed
- Made `Clear-LogFile` resilient when `Initialize-Logger` is unavailable by conditionally invoking it only when present.
- Added a fallback `Write-LogMessage` implementation in the root module entrypoint so manifest-based imports work in isolated test environments.

## [2.2.0] - 2026-03-27
### Added
- Added `-BeforeTimestamp` (`[datetime]`) to `Clear-LogFile` for explicit cutoff-based log entry filtering.

### Changed
- Updated `Clear-LogFile` execution flow so timestamp filtering (`-BeforeTimestamp` / `-RetentionDays`) can be combined with truncation options in a single call, preserving FileDistributor startup behavior while using shared module logic.
- Expanded timestamp parsing for filter operations to handle both bracketed and plain leading timestamps.


## [2.1.1] - 2026-03-26
### Fixed
- Updated the active module entrypoint (`src/powershell/modules/Core/Logging/PurgeLogs.psm1`) so exported `ConvertTo-Bytes` accepts both single-letter and two-letter suffixes (`K/KB`, `M/MB`, `G/GB`), matching documented 2.1.0 behavior.
- Updated PurgeLogs tests to import via module manifest (`PurgeLogs.psd1`) so tests validate production import/export paths instead of dot-sourcing a standalone script.

## [2.1.0] - 2026-03-26
### Changed
- Expanded `ConvertTo-Bytes` to accept both single-letter and two-letter size suffixes:
  - `K` / `KB`
  - `M` / `MB`
  - `G` / `GB`
- Preserved existing byte conversion behavior for current `KB`/`MB`/`GB` inputs while adding support for `K`/`M`/`G`.
- Updated `ConvertTo-Bytes` help/examples and module README examples to document both accepted forms.

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
