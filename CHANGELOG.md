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
- **Naming Conventions Documentation** (#454) - Comprehensive naming standards for all scripts
  - New document: `docs/guides/naming-conventions.md` - Complete naming conventions guide with examples
  - New document: `docs/RENAME_MAPPING.md` - Detailed mapping of all renamed scripts with justifications
  - Establishes PowerShell `Verb-Noun` PascalCase standard using approved verbs
  - Establishes Python `snake_case` standard per PEP 8
  - Includes validation methods, migration guide, and FAQs

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
- **⚠️ BREAKING: Standardized Script Naming Conventions** (#454) - All scripts renamed to follow language best practices
  - **PowerShell Scripts** (19 renamed):
    - `logCleanup.ps1` → `Clear-PostgreSqlLog.ps1`
    - `cleanup-git-branches.ps1` → `Remove-MergedGitBranch.ps1`
    - `picconvert.ps1` → `Convert-ImageFile.ps1`
    - `post-commit-my-scripts.ps1` → `Invoke-PostCommitHook.ps1`
    - `post-merge-my-scripts.ps1` → `Invoke-PostMergeHook.ps1`
    - `DeleteOldDownloads.ps1` → `Remove-OldDownload.ps1`
    - `scrubname.ps1` → `Remove-FilenameString.ps1`
    - `videoscreenshot.ps1` → `Show-VideoscreenshotDeprecation.ps1`
    - `job_scheduler_pg_backup.ps1` → `Backup-JobSchedulerDatabase.ps1`
    - `purge_logs.ps1` → `Clear-LogFile.ps1`
    - `recover-extensions.ps1` → `Restore-FileExtension.ps1`
    - `handle.ps1` → `Get-FileHandle.ps1`
    - `pgconnect.ps1` → `Test-PostgreSqlConnection.ps1`
    - `WLANsvc.ps1` → `Restart-WlanService.ps1`
    - `cloudconvert_driver.ps1` → `Invoke-CloudConvert.ps1`
    - `SelObj.ps1` → `Show-RandomImage.ps1`
    - `gnucash_pg_backup.ps1` → `Backup-GnuCashDatabase.ps1`
    - `pg_backup_common.ps1` → `Backup-PostgreSqlCommon.ps1`
    - `timeline_data_pg_backup.ps1` → `Backup-TimelineDatabase.ps1`
  - **Python Scripts** (2 renamed):
    - `csv-to-gpx.py` → `csv_to_gpx.py`
    - `find-duplicate-images.py` → `find_duplicate_images.py`
  - Updated all references in:
    - Windows Task Scheduler XML files
    - Test files
    - Documentation
    - Batch wrappers
    - Module documentation
  - Git history preserved for all renames using `git mv`
  - See `docs/RENAME_MAPPING.md` for complete mapping and migration guide

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
