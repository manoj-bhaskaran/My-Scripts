# Changelog

All notable changes to the My-Scripts repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Semantic Versioning Strategy

This repository uses semantic versioning (MAJOR.MINOR.PATCH) at the repository level:

- **MAJOR**: Breaking changes to script interfaces or module APIs
- **MINOR**: New features (new scripts, module enhancements, non-breaking functionality)
- **PATCH**: Bug fixes, documentation updates, minor corrections

Individual scripts and modules maintain their own version numbers and changelogs. See module-specific CHANGELOG files (e.g., `src/powershell/module/Videoscreenshot/CHANGELOG.md`) for component-level changes.

---

## [Unreleased]

### Added
- Root `VERSION` file for repository-level semantic versioning
- Root `CHANGELOG.md` following Keep a Changelog format with semantic versioning strategy
- Versioning documentation in `docs/guides/versioning.md`
- Version validation script for ensuring VERSION file matches CHANGELOG entries

### Changed
- Restructured CHANGELOG.md to follow Keep a Changelog format strictly
- Consolidated historical changes into versioned releases

---

## [2.0.0] - 2025-11-16

### Added
- **Comprehensive Testing Framework** (#466, #469, #470, #471, #472)
  - Python unit tests using pytest framework
    - `tests/python/unit/test_validators.py` - Input validation function tests
    - `tests/python/unit/test_logging_framework.py` - Logging framework tests
    - `tests/python/unit/test_csv_to_gpx.py` - CSV to GPX conversion tests
  - PowerShell unit tests using Pester framework
    - `tests/powershell/unit/RandomName.Tests.ps1` - RandomName module tests
    - `tests/powershell/unit/FileDistributor.Tests.ps1` - FileDistributor script tests
  - Test infrastructure files
    - `pytest.ini` - pytest configuration
    - `tests/python/conftest.py` - Shared pytest fixtures and configuration
  - Testing documentation
    - `tests/README.md` - Comprehensive guide on running and writing tests
    - `docs/guides/testing.md` - Testing standards and best practices
  - Coverage reporting integrated with SonarCloud
  - Python test dependencies: pytest >= 7.4.0, pytest-cov >= 4.1.0, pytest-mock >= 3.11.1

- **Centralized Logging Framework** (#338, #441, #442)
  - Cross-platform logging framework for Python, PowerShell, and Batch scripts
  - `src/common/python_logging_framework.py` - Python logging module
  - `src/common/PowerShellLoggingFramework.psm1` - PowerShell logging module
  - Unified log format with timestamps, levels, and structured metadata
  - `docs/logging_specification.md` - Comprehensive logging framework documentation
  - Log purge mechanism with retention management
    - `src/common/PurgeLogs.psm1` - PowerShell log purge module
    - `src/powershell/purge_logs.ps1` - Standalone purge script
  - Refactored all PowerShell and batch scripts to use centralized logging

- **Monthly System Health Check** (#414)
  - `src/powershell/system-maintenance/Invoke-SystemHealthCheck.ps1` (v1.0.0) - Automated SFC and DISM maintenance
  - `src/powershell/system-maintenance/Install-SystemHealthCheckTask.ps1` (v1.0.0) - Scheduled task setup automation
  - Task scheduler XML configuration for monthly maintenance
  - `docs/system-health-check.md` - Installation, usage, and troubleshooting documentation
  - Features: monthly scheduling, administrator privileges, timestamped logs, disk space validation

- **Repository Documentation and Standards**
  - Comprehensive repository review and improvement roadmap (#448)
  - `CONTRIBUTING.md` (v1.0.0) - Contributing guidelines with logging framework documentation
  - Testing guidelines and best practices documentation
  - Code standards and security best practices

- **Development Tooling**
  - `src/bash/create_github_issues.sh` - Script for creating GitHub issues from markdown templates (#438)
  - Pre-commit hooks for code quality enforcement
  - SonarCloud integration for continuous code quality monitoring
  - Automated CI/CD pipeline improvements

### Changed
- Updated `requirements.txt` to include pytest and coverage dependencies
- Enhanced `.github/workflows/sonarcloud.yml` with:
  - Python test execution with coverage reporting
  - PowerShell test execution using Pester with code coverage
  - Coverage report uploads to SonarCloud
  - Non-blocking quality gate for testing framework integration
- Updated root `README.md` with:
  - System Maintenance category in features
  - Featured Scripts and Tools section with documentation links
  - Testing section with instructions
- Normalized line endings across all PowerShell scripts
- Improved FileDistributor script with enhanced validation and error handling (v3.1.16-v3.1.17)

### Fixed
- SonarCloud scan made non-blocking in CI workflow (#472)
- SonarCloud quality gate bypass for testing framework PR (#472)
- Included PowerShell module files (.psm1) in SonarCloud analysis (#472)
- Made path validation tests platform-aware (#472)
- Rewrote FileDistributor tests to focus on testable logic (#472)
- Resolved PowerShell file paths for Pester code coverage (#472)
- Fixed PowerShell hook error in post-merge script (#447)
- Eliminated dual-processing in FileDistributor subfolder validation (v3.1.17)
- Fixed subfolder validation to preserve DirectoryInfo objects in FileDistributor (v3.1.16)
- Corrected redistribution subfolder validation in FileDistributor

### Infrastructure
- CI/CD pipeline runs all tests automatically on push and pull requests
- Test execution completes in under 2 minutes
- Coverage reports generated in XML format for SonarCloud integration
- Automated test result artifacts uploaded for each CI run
- Added `logs` directory to `.gitignore` (#451)
- Added test coverage files to `.gitignore`

### Coverage Targets
- Shared modules (src/common/): ≥30%
- Core utilities: ≥50%
- Overall project: ≥25%

---

## [1.0.0] - 2025-09-14

### Added
- **PowerShell Modules**
  - Videoscreenshot module (v3.0.1)
    - Video frame capture via VLC (snapshots) or GDI+ (desktop capture)
    - Python cropper integration for automated image processing
    - Support for .mp4, .mkv, .avi, .mov, .m4v, .wmv formats
    - Comprehensive module structure with Public/ and Private/ components
    - `Start-VideoBatch` as public entrypoint
    - Resume and processed-log support
    - Structured logging with timestamped output
    - Module manifest and comprehensive README
    - Module CHANGELOG (src/powershell/module/Videoscreenshot/CHANGELOG.md)
  - RandomName module (v2.1.0)
    - Windows-safe random filename generation
    - Conservative allow-list based character selection
    - MaxAttempts parameter for collision handling
    - Module manifest and documentation

- **Core PowerShell Scripts**
  - FileDistributor (v3.5.0) - Intelligent file distribution across subdirectories
  - DeleteOldDownloads - Automated cleanup of old downloaded files
  - Various utility scripts for file operations and system maintenance

- **Python Scripts**
  - crop_colours.py - Image cropping based on color analysis
  - csv_to_gpx.py - GPS track conversion from CSV to GPX format
  - Input validation utilities
  - Common utility functions

- **Batch Scripts**
  - File management automation
  - System maintenance wrappers

- **Repository Structure**
  - Language-based organization (src/powershell/, src/python/, src/bash/, src/batch/)
  - Common shared modules in src/common/
  - Documentation in docs/
  - Module structure for PowerShell components

- **Documentation**
  - Repository README with feature overview
  - Module-specific README files
  - Inline documentation and comment-based help
  - Script usage examples

### Changed
- Established consistent directory structure by language
- Implemented module-based architecture for PowerShell scripts
- Standardized naming conventions (PowerShell: Verb-Noun, Python: snake_case)

### Notes
- This release establishes the baseline for the repository structure
- Historical changes to individual scripts prior to this release are documented in git commit history
- Module-specific changelogs track component-level changes

---

## Version References

- **Repository Version**: Tracked in `VERSION` file at repository root
- **Module Versions**: Each PowerShell module maintains its own version in manifest (.psd1) file
- **Script Versions**: Individual scripts may include version information in headers

For detailed module-level changes:
- Videoscreenshot module: `src/powershell/module/Videoscreenshot/CHANGELOG.md`
- RandomName module: See module manifest `src/powershell/module/RandomName/RandomName.psd1`

For script-level changes, refer to git commit history or script headers.

---

[unreleased]: https://github.com/manoj-bhaskaran/My-Scripts/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/manoj-bhaskaran/My-Scripts/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/manoj-bhaskaran/My-Scripts/releases/tag/v1.0.0
