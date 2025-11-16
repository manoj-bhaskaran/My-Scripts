# My Scripts Collection – Changelog

All notable changes to the **My Scripts Collection** repository are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file tracks repository-wide changes. For module-specific changes, see the respective CHANGELOG files (e.g., `src/powershell/module/Videoscreenshot/CHANGELOG.md`).

---

## [Unreleased]

### Added
- **Batch Script Logging Framework** (#338): Implemented standardized logging for all Windows Batch scripts to conform to the PowerShell logging standard.
  - Created logging functions with standardized format: `[YYYY-MM-DD HH:mm:ss.fff TIMEZONE] [LEVEL] [ScriptName] [HostName] [PID] Message`
  - Log files are stored in `src/batch/logs/` directory with naming convention: `<scriptname>_batch_YYYY-MM-DD.log`
  - Automatic log directory creation if it doesn't exist
  - Multiple log levels supported: INFO, WARNING, ERROR
  - Leverages PowerShell for accurate timestamps, timezone detection, hostname, and PID retrieval
  - All significant operations are now logged with appropriate context

- **Test Documentation**: Created comprehensive test plan for batch script logging (`docs/batch-logging-test-plan.md`)
  - 13 detailed test cases covering log creation, format validation, error handling, and performance
  - Test sign-off checklist for quality assurance
  - Documentation of edge cases and issues to watch for

### Changed
- **RunDeleteOldDownloads.bat** (v2.1 → v3.0.0):
  - Refactored with standardized logging framework
  - All operations (PowerShell detection, script execution, success/failure) are now logged
  - Improved error tracking with detailed exit codes
  - Added logging for MessageBox display on failures

- **printcancel.cmd** (initial → v2.0.0):
  - Complete refactoring with standardized logging framework
  - Enhanced error handling with exit code management
  - Detailed logging of all spooler operations (stop service, delete files, start service)
  - Added proper script header with version information
  - Improved code structure with labeled sections

### Documentation
- Added batch script logging information to repository documentation
- Created detailed test plan for validating logging functionality
- Updated inline documentation in batch scripts with version history

### Technical Details
- **Log Format Compliance**: All batch scripts now conform to the same logging format used by PowerShellLoggingFramework.psm1
- **Date Handling**: Uses WMIC for reliable date formatting (YYYY-MM-DD)
- **Timestamp Precision**: Millisecond-accurate timestamps via PowerShell
- **Append Behavior**: Multiple executions on the same day append to the same log file
- **Performance Impact**: Minimal overhead per logging call

---

## [1.0.0] - 2025-11-16

### Initial Release
- Established CHANGELOG for tracking repository-wide changes
- Repository contains PowerShell, Python, Batch, and SQL scripts
- Organized structure with source code in `src/` directory
- Common logging framework established for PowerShell scripts
- Documentation and testing infrastructure in place

---

## Legend

- **Added**: New features or capabilities
- **Changed**: Changes to existing functionality
- **Deprecated**: Features that will be removed in future versions
- **Removed**: Features that have been removed
- **Fixed**: Bug fixes
- **Security**: Security-related changes
- **Breaking**: Breaking changes that may require user action

---

## Version History

Individual script versions:
- `RunDeleteOldDownloads.bat`: v3.0.0
- `printcancel.cmd`: v2.0.0
- `DeleteOldDownloads.ps1`: v1.2.1
- `Videoscreenshot Module`: v3.0.1

For detailed version history of individual scripts and modules, see their respective CHANGELOG files or script headers.
