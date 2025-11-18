# Versioning Guide

This guide explains the versioning strategy for the My-Scripts repository, covering repository-level versions, module versions, and script versions.

## Table of Contents

- [Overview](#overview)
- [Semantic Versioning](#semantic-versioning)
- [Repository Version](#repository-version)
- [Module Versions](#module-versions)
- [Script Versions](#script-versions)
- [Version Update Workflow](#version-update-workflow)
- [Git Tagging Strategy](#git-tagging-strategy)
- [Version Validation](#version-validation)
- [Best Practices](#best-practices)

---

## Overview

The My-Scripts repository uses a **multi-level versioning strategy**:

1. **Repository Level**: Tracks major infrastructure changes and cross-cutting features
2. **Module Level**: Each PowerShell module maintains its own semantic version
3. **Script Level**: Individual scripts may include version information in headers

This approach allows independent evolution of components while maintaining overall repository versioning for major milestones.

---

## Semantic Versioning

All versions in this repository follow [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):

```
MAJOR.MINOR.PATCH
```

### Repository-Level Versioning

- **MAJOR**: Breaking changes to script interfaces or module APIs
  - Example: Removing a public function, changing required parameters
- **MINOR**: New features, new scripts, module enhancements (non-breaking)
  - Example: Adding a new script, adding optional parameters
- **PATCH**: Bug fixes, documentation updates, minor corrections
  - Example: Fixing a bug, updating README

### Module-Level Versioning

Each PowerShell module follows its own semantic versioning:

- **MAJOR**: Breaking changes to module API
- **MINOR**: New features, non-breaking enhancements
- **PATCH**: Bug fixes, documentation updates

### Script-Level Versioning

Individual scripts may include version numbers in their headers, following similar principles:

- **MAJOR**: Breaking changes to script interface
- **MINOR**: New features, enhancements
- **PATCH**: Bug fixes, minor improvements

---

## Repository Version

### Location

The repository version is stored in the `VERSION` file at the repository root:

```
/home/user/My-Scripts/VERSION
```

**Format**: Single line containing the semantic version number

**Example**:
```
2.0.0
```

### When to Update

Update the repository version when:

1. **Major infrastructure changes** affecting multiple scripts
2. **New major features** or capabilities are added
3. **Breaking changes** to script interfaces or APIs
4. **Significant milestones** in repository development

### Current Version

As of this writing, the current repository version is **2.0.0**, reflecting:

- Comprehensive testing framework (pytest, Pester)
- Centralized logging framework
- CI/CD integration with SonarCloud
- Code quality tooling and pre-commit hooks

---

## Module Versions

### PowerShell Modules

PowerShell modules maintain version information in their manifest files (`.psd1`):

#### Videoscreenshot Module

**Manifest**: `src/powershell/module/Videoscreenshot/Videoscreenshot.psd1`

**Current Version**: 3.0.2

**CHANGELOG**: `src/powershell/module/Videoscreenshot/CHANGELOG.md`

The Videoscreenshot module has its own detailed CHANGELOG following Keep a Changelog format.

#### RandomName Module

**Manifest**: `src/powershell/module/RandomName/RandomName.psd1`

**Current Version**: 2.1.0

**Version Tracking**: Module manifest `ModuleVersion` field

### Updating Module Versions

When updating a module version:

1. Update the `ModuleVersion` field in the module manifest (`.psd1`)
2. Update the module's CHANGELOG if it exists
3. Document the change in the module's release notes
4. Consider whether the change warrants a repository-level version bump

**Example** (Videoscreenshot.psd1):
```powershell
@{
  RootModule        = 'Videoscreenshot.psm1'
  ModuleVersion     = '3.0.2'
  # ... other fields
}
```

---

## Script Versions

Individual scripts may include version information in their headers:

### PowerShell Scripts

```powershell
<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description

.NOTES
    Author: Manoj Bhaskaran
    Version: 3.5.0
    Last Modified: 2025-11-16
#>
```

### Python Scripts

```python
#!/usr/bin/env python3
"""
Script: script_name.py
Description: Brief description of what this script does
Author: Manoj Bhaskaran
Version: 1.0.0
Last Modified: 2025-11-16
"""
```

### When to Update Script Versions

- **MAJOR**: Breaking changes to command-line interface or parameters
- **MINOR**: New features or capabilities
- **PATCH**: Bug fixes or minor improvements

---

## Version Update Workflow

Follow this workflow when releasing a new version:

### Step 1: Update CHANGELOG.md

Move unreleased changes to a new version section:

```markdown
## [Unreleased]

### Added
### Changed
### Fixed

## [X.Y.Z] - YYYY-MM-DD

### Added
- Feature 1
- Feature 2

### Changed
- Change 1

### Fixed
- Bug fix 1
```

### Step 2: Update VERSION File

Update the `VERSION` file at the repository root:

```bash
echo "X.Y.Z" > VERSION
```

### Step 3: Update Module Manifests (if applicable)

If module versions changed, update the manifest files:

```powershell
# Example: Update Videoscreenshot module version
# Edit src/powershell/module/Videoscreenshot/Videoscreenshot.psd1
ModuleVersion = 'X.Y.Z'
```

### Step 4: Commit Changes

Create a commit for the version bump:

```bash
git add VERSION CHANGELOG.md
git add src/powershell/module/*//*.psd1  # if module versions changed
git commit -m "chore: release vX.Y.Z"
```

### Step 5: Create Git Tag

Tag the release:

```bash
git tag -a vX.Y.Z -m "Release X.Y.Z"
```

### Step 6: Push Changes

Push the commit and tag:

```bash
git push origin main
git push origin vX.Y.Z
```

---

## Git Tagging Strategy

### Tag Format

Tags follow the format: `vMAJOR.MINOR.PATCH`

**Examples**:
- `v1.0.0`
- `v2.0.0`
- `v2.1.0`

### Tag Message

Tag messages should reference the CHANGELOG section:

```bash
git tag -a v2.0.0 -m "Release 2.0.0

Major features:
- Comprehensive testing framework
- Centralized logging framework
- CI/CD integration

See CHANGELOG.md for full details."
```

### When to Create Tags

Create tags for:

1. **Major releases** (X.0.0)
2. **Minor releases** (X.Y.0)
3. **Patch releases** (X.Y.Z) - optional, at maintainer's discretion

### Existing Tags

- `v1.0.0` - Initial structured release (baseline)
- `v2.0.0` - Testing framework and logging infrastructure

---

## Version Validation

### Validation Script

A version validation script ensures consistency between `VERSION` file and `CHANGELOG.md`:

**Script**: `scripts/validate_version.py` or `scripts/Validate-Version.ps1`

### What It Validates

1. `VERSION` file matches the latest version in `CHANGELOG.md`
2. Version format follows semantic versioning (MAJOR.MINOR.PATCH)
3. Version in `CHANGELOG.md` has a valid date
4. Links at the bottom of `CHANGELOG.md` are correct

### Running Validation

```bash
# Python
python scripts/validate_version.py

# PowerShell
pwsh scripts/Validate-Version.ps1
```

### Pre-commit Hook

The validation script can be integrated into a pre-commit hook to prevent invalid version commits:

```bash
# .git/hooks/pre-commit
#!/bin/bash
python scripts/validate_version.py
if [ $? -ne 0 ]; then
    echo "Version validation failed. Please fix before committing."
    exit 1
fi
```

---

## Best Practices

### DO

✅ **Update CHANGELOG before tagging**: Always document changes before creating a release tag

✅ **Follow semantic versioning strictly**: Breaking changes = MAJOR, features = MINOR, fixes = PATCH

✅ **Keep module versions independent**: Modules can have different versions from repository version

✅ **Document breaking changes clearly**: Use "BREAKING CHANGE:" prefix in commit messages

✅ **Reference issue numbers**: Link CHANGELOG entries to GitHub issues (#123)

✅ **Use descriptive tag messages**: Include key highlights in tag annotation

✅ **Validate before release**: Run validation script before creating tags

### DON'T

❌ **Don't skip version updates**: Every release should bump the version

❌ **Don't create tags without CHANGELOG updates**: Tags should always reference CHANGELOG

❌ **Don't mix unreleased and released**: Keep clear separation in CHANGELOG

❌ **Don't forget to push tags**: Use `git push --tags` or `git push origin vX.Y.Z`

❌ **Don't backdate versions**: Use actual release date in CHANGELOG

❌ **Don't reuse version numbers**: Each version is immutable once released

---

## Version Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Make Changes                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         Update CHANGELOG.md [Unreleased] Section            │
│         Document all changes as you work                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Ready to Release?                              │
└────────────────────┬────────────────────────────────────────┘
                     │ Yes
                     ▼
┌─────────────────────────────────────────────────────────────┐
│   1. Move [Unreleased] → [X.Y.Z] in CHANGELOG.md           │
│   2. Update VERSION file                                    │
│   3. Update module manifests (if applicable)                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│           Run Version Validation Script                     │
└────────────────────┬────────────────────────────────────────┘
                     │ Pass
                     ▼
┌─────────────────────────────────────────────────────────────┐
│        git commit -m "chore: release vX.Y.Z"                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│        git tag -a vX.Y.Z -m "Release X.Y.Z"                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              git push origin main --tags                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Examples

### Example 1: Patch Release

A bug fix is made to a script:

```bash
# 1. Update CHANGELOG.md
## [Unreleased]
### Fixed
- Fixed FileDistributor path validation bug (#456)

# Becomes:
## [2.0.1] - 2025-11-20
### Fixed
- Fixed FileDistributor path validation bug (#456)

# 2. Update VERSION
echo "2.0.1" > VERSION

# 3. Commit and tag
git add VERSION CHANGELOG.md
git commit -m "chore: release v2.0.1"
git tag -a v2.0.1 -m "Release 2.0.1 - Bug fixes"
git push origin main --tags
```

### Example 2: Minor Release

A new script is added:

```bash
# 1. Update CHANGELOG.md
## [2.1.0] - 2025-12-01
### Added
- New PowerShell script for automated system diagnostics
- Enhanced logging in backup scripts

# 2. Update VERSION
echo "2.1.0" > VERSION

# 3. Commit and tag
git add VERSION CHANGELOG.md
git commit -m "chore: release v2.1.0"
git tag -a v2.1.0 -m "Release 2.1.0 - New diagnostics script"
git push origin main --tags
```

### Example 3: Major Release with Breaking Changes

A breaking API change is made:

```bash
# 1. Update CHANGELOG.md
## [3.0.0] - 2026-01-15
### Changed
- **BREAKING**: Renamed `Start-VideoBatch` to `Invoke-VideoBatch`
- **BREAKING**: Removed deprecated `-LegacyMode` parameter

### Added
- New async processing capabilities

# 2. Update VERSION
echo "3.0.0" > VERSION

# 3. Update module version
# Edit Videoscreenshot.psd1: ModuleVersion = '4.0.0'

# 4. Commit and tag
git add VERSION CHANGELOG.md src/powershell/module/Videoscreenshot/Videoscreenshot.psd1
git commit -m "chore: release v3.0.0

BREAKING CHANGE: Renamed Start-VideoBatch to Invoke-VideoBatch
BREAKING CHANGE: Removed deprecated -LegacyMode parameter"
git tag -a v3.0.0 -m "Release 3.0.0 - Major API changes"
git push origin main --tags
```

---

## References

- [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)
- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- Repository CHANGELOG: `/CHANGELOG.md`
- Repository VERSION: `/VERSION`

---

**Last Updated**: 2025-11-18
**Version**: 1.0.0
