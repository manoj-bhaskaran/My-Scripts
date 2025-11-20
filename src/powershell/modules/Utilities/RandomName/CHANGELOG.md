# RandomName Module – Changelog

All notable changes to the **RandomName PowerShell module** are documented here.
The project follows [Semantic Versioning](https://semver.org) and the structure is inspired by
[Keep a Changelog](https://keepachangelog.com).

> This file is module-scoped. For repository-wide changes affecting other scripts, see the root `CHANGELOG.md`.

## [2.1.0] - 2024-11-19
### Added
- Comprehensive module documentation (README.md, CHANGELOG.md)
- Module manifest (.psd1) with metadata, tags, and version tracking
- Initial versioned release tracking

### Changed
- Updated documentation to reflect current functionality

## [2.0.0] - (Prior Release)
### Added
- Windows-safe filename generation using conservative allow-list approach
- Configurable length parameters (MinimumLength, MaximumLength)
- Protection against Windows reserved device names
- MaxAttempts parameter for retry logic
- Parameter aliases for brevity (min/max)
- Validation against Windows invalid filename characters
- Cross-platform compatibility

### Features
- First character limited to alphanumeric for maximum compatibility
- Subsequent characters include alphanumeric plus `_`, `-`, `~`
- Automatic validation against reserved names: CON, PRN, AUX, NUL, COM1-9, LPT1-9
- Configurable length range (1-255 characters)
- Uses `Get-Random` for generation

## [Unreleased]
### Planned
- Optional cryptographically secure random number generation
- Custom character set support
- Prefix/suffix parameters
- Extension parameter for direct file path generation

---

For usage examples and detailed documentation, see [README.md](./README.md).
