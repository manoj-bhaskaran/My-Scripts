# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2025-11-16

### Added

#### Documentation
- **CONTRIBUTING.md**: Comprehensive developer guidelines including:
  - Logging framework usage documentation for Python, PowerShell, and Batch scripts
  - Complete examples for all supported languages
  - Log purge mechanism documentation with scheduling instructions
  - Code standards and best practices
  - Security guidelines for logging
  - Testing and version control practices

- **CHANGELOG.md**: Version history tracking following Keep a Changelog format

- **VERSION**: Repository version file tracking releases

- **README.md**: Enhanced with logging framework section including:
  - Quick start guide for Python and PowerShell logging
  - Key features overview
  - Links to comprehensive documentation
  - Log storage and naming pattern information

#### Logging Framework
The following logging framework components were previously implemented and are now formally documented:

- **Python Logging Framework** (`src/common/python_logging_framework.py`):
  - Standardized log formatting with IST timezone support
  - Level-specific logging functions (DEBUG, INFO, WARNING, ERROR, CRITICAL)
  - Metadata support for structured logging
  - JSON output format option
  - Automatic directory creation and fallback to console

- **PowerShell Logging Framework** (`src/common/PowerShellLoggingFramework.psm1`):
  - Unified log format matching Python implementation
  - Five log levels with numeric constants
  - Metadata validation against recommended keys
  - JSON structured logging support
  - Automatic script name and path resolution

- **Log Purge Module** (`src/common/PurgeLogs.psm1`):
  - Four purge strategies: retention-based, size-based, threshold-based, and unconditional
  - `Clear-LogFile` cmdlet with dry-run support
  - Size unit conversion utilities
  - Integration with PowerShell logging framework

- **Purge Script** (`src/powershell/purge_logs.ps1`):
  - CLI wrapper for log purge module
  - Support for all purge strategies
  - Verbose output for monitoring

- **Logging Specification** (`docs/logging_specification.md`):
  - Language-agnostic log format specification
  - Cross-platform implementation guidelines
  - Security and compliance requirements
  - Metadata standards and recommendations

### Changed
- Repository now has formal versioning starting at 1.0.0
- Documentation structure enhanced with clear navigation and examples

### Notes
- This release formalizes the existing logging framework with comprehensive documentation
- All future scripts should use the documented logging framework per CONTRIBUTING.md guidelines
- Existing scripts should be migrated to the framework during maintenance cycles

---

## Legend

- **Added**: New features or functionality
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements or fixes

---

[1.0.0]: https://github.com/manoj-bhaskaran/My-Scripts/releases/tag/v1.0.0
