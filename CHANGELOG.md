# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive testing framework setup for Python and PowerShell code
- Python unit tests using pytest:
  - `tests/python/unit/test_validators.py` - Tests for input validation functions
  - `tests/python/unit/test_logging_framework.py` - Tests for logging framework
  - `tests/python/unit/test_csv_to_gpx.py` - Tests for CSV to GPX conversion
- PowerShell unit tests using Pester:
  - `tests/powershell/unit/RandomName.Tests.ps1` - Tests for RandomName module
  - `tests/powershell/unit/FileDistributor.Tests.ps1` - Tests for FileDistributor script
- Test infrastructure files:
  - `pytest.ini` - pytest configuration
  - `tests/python/conftest.py` - Shared pytest fixtures and configuration
- Testing documentation:
  - `tests/README.md` - Comprehensive guide on running and writing tests
  - `docs/guides/testing.md` - Testing standards and best practices
- Coverage reporting integrated with SonarCloud
- Python dependencies for testing:
  - pytest >= 7.4.0
  - pytest-cov >= 4.1.0
  - pytest-mock >= 3.11.1

### Changed
- Updated `requirements.txt` to include pytest and coverage dependencies
- Enhanced `.github/workflows/sonarcloud.yml` with:
  - Python test execution with coverage reporting
  - PowerShell test execution using Pester with code coverage
  - Coverage report uploads to SonarCloud
  - Updated SonarCloud configuration to include coverage data
- Updated root `README.md` with testing section and instructions

### Infrastructure
- CI/CD pipeline now runs all tests automatically on push and pull requests
- Test execution completes in under 2 minutes
- Coverage reports are generated in XML format for SonarCloud integration
- Automated test result artifacts uploaded for each CI run

### Coverage Targets
- Shared modules (src/common/): ≥30%
- Core utilities: ≥50%
- Overall project: ≥25%

## [Previous Releases]

For changes prior to the testing framework implementation, see the Git commit history.
# My Scripts Collection – Changelog

All notable repository-wide changes are documented here.
This file tracks major features, infrastructure changes, and cross-cutting updates affecting multiple scripts.

The project follows [Semantic Versioning](https://semver.org) at the repository level, and the structure is inspired by [Keep a Changelog](https://keepachangelog.com).

> **Note**: Individual scripts and modules maintain their own version numbers and changelogs. See script headers or module-specific CHANGELOG files (e.g., `src/powershell/module/Videoscreenshot/CHANGELOG.md`) for component-level changes.

---

## [Unreleased]

### Added
- **Monthly System Health Check** (#414) - Automated Windows system maintenance solution
  - New script: `Invoke-SystemHealthCheck.ps1` (v1.0.0) - Runs SFC and DISM operations with comprehensive logging
  - New script: `Install-SystemHealthCheckTask.ps1` (v1.0.0) - Automated setup for scheduled task configuration
  - Task scheduler XML: `Monthly System Health Check.xml` - Pre-configured monthly maintenance task
  - Comprehensive documentation: `docs/system-health-check.md` with installation, usage, and troubleshooting guides
  - Features:
    - Runs monthly on the 1st of each month at 2:00 AM
    - Executes with Administrator privileges automatically
    - Captures timestamped logs for review
    - Validates disk space and provides duration tracking
    - Includes detailed summary reports

### Changed
- Updated `README.md` to include System Maintenance category in features
- Added Featured Scripts and Tools section to README with links to documentation

---

## Notes on Versioning

This repository contains multiple independent scripts and modules, each with its own version number:

- **Repository-level versions** (this file): Track major infrastructure changes, new script additions, and cross-cutting features
- **Script-level versions**: Individual scripts may include version information in their headers
- **Module-level versions**: PowerShell modules maintain their own CHANGELOG files (e.g., Videoscreenshot module)

When referencing versions:
- For specific script changes, see the script header or module CHANGELOG
- For repository-wide changes affecting multiple scripts, refer to this file

---

## Version History

_This is the initial version of the repository-level CHANGELOG. Previous changes to individual scripts are documented in their respective files or commit history._

---
