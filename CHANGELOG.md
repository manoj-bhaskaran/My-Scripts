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
