# Naming Conventions

**Document Version:** 1.0.0
**Last Updated:** 2025-11-18
**Issue:** #454

This document defines the standardized naming conventions for all scripts and modules in the My-Scripts repository.

---

## Table of Contents

- [Overview](#overview)
- [PowerShell Scripts](#powershell-scripts)
  - [Verb-Noun Pattern](#verb-noun-pattern)
  - [Approved Verbs](#approved-verbs)
  - [Naming Examples](#naming-examples-powershell)
- [Python Scripts](#python-scripts)
  - [snake_case Convention](#snake_case-convention)
  - [Naming Examples](#naming-examples-python)
- [Modules](#modules)
- [Configuration Files](#configuration-files)
- [Validation](#validation)
- [References](#references)

---

## Overview

Consistent naming conventions improve:
- **Discoverability** - Users know what pattern to search for
- **Professionalism** - Code looks polished and well-maintained
- **Tooling** - Linters and automation work better with standard names
- **Tab Completion** - Shells can predictably complete script names

All scripts must follow language-specific best practices:
- **PowerShell**: `Verb-Noun` with PascalCase
- **Python**: `module_name` with snake_case

---

## PowerShell Scripts

### Verb-Noun Pattern

All PowerShell scripts **MUST** follow the `Verb-Noun.ps1` pattern where:

1. **Verb** - An approved PowerShell verb (see [Approved Verbs](#approved-verbs))
2. **Noun** - A singular, descriptive noun
3. **Format** - Both parts use PascalCase

**Pattern:** `<Verb>-<Noun>.ps1`

### Approved Verbs

PowerShell verbs must come from the [official approved verb list](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands).

To view all approved verbs:
```powershell
Get-Verb | Format-Table Verb, Group, Description
```

#### Common Approved Verbs by Category

| Category | Verbs | Purpose |
|----------|-------|---------|
| **Common** | Add, Clear, Get, New, Remove, Set, Show | General actions |
| **Data** | Backup, Convert, Export, Import, Restore | Data operations |
| **Lifecycle** | Invoke, Restart, Start, Stop, Wait | Process/service control |
| **Diagnostic** | Debug, Test, Trace | Testing and debugging |
| **Security** | Block, Grant, Protect, Revoke, Unblock | Security operations |

#### Verbs to Avoid

❌ **Non-Approved Verbs** (use approved alternatives):

| ❌ Don't Use | ✅ Use Instead | Example |
|-------------|---------------|---------|
| `Delete` | `Remove` | `Remove-OldFile.ps1` |
| `Create` | `New` | `New-Configuration.ps1` |
| `Cleanup` | `Clear` or `Remove` | `Clear-LogFile.ps1` |
| `Execute` | `Invoke` | `Invoke-Task.ps1` |
| `Display` | `Show` or `Write` | `Show-Report.ps1` |
| `Retrieve` | `Get` | `Get-Data.ps1` |

### Naming Rules

1. **Use Singular Nouns**
   - ✅ `Remove-File.ps1`, `Get-Process.ps1`
   - ❌ `Remove-Files.ps1`, `Get-Processes.ps1`

2. **Be Specific but Concise**
   - ✅ `Backup-GnuCashDatabase.ps1`
   - ❌ `Backup-Database.ps1` (too generic)
   - ❌ `Backup-GnuCashDatabaseToBackupLocationWithCompression.ps1` (too verbose)

3. **Use PascalCase for Both Parts**
   - ✅ `Move-ImageFileToBatch.ps1`
   - ❌ `move-imagefiletobatch.ps1`, `Move-image_file_to_batch.ps1`

4. **Avoid Abbreviations** (except well-known ones)
   - ✅ `Test-PostgreSqlConnection.ps1`, `Get-HttpResponse.ps1`
   - ❌ `Test-PgConn.ps1`, `Get-HttResp.ps1`

### Naming Examples (PowerShell)

| Script Purpose | ✅ Correct Name | ❌ Incorrect Names |
|----------------|----------------|-------------------|
| Remove old log files | `Clear-LogFile.ps1` | `logCleanup.ps1`, `purge_logs.ps1`, `Delete-Logs.ps1` |
| Backup database | `Backup-Database.ps1` | `backup_db.ps1`, `db-backup.ps1`, `DatabaseBackup.ps1` |
| Test network connection | `Test-NetworkConnection.ps1` | `ping.ps1`, `testConnection.ps1`, `network-test.ps1` |
| Convert images | `Convert-Image.ps1` | `picconvert.ps1`, `imageConverter.ps1`, `convert_img.ps1` |
| Get file handles | `Get-FileHandle.ps1` | `handle.ps1`, `getHandles.ps1`, `file-handles.ps1` |
| Invoke Git hook | `Invoke-PostCommitHook.ps1` | `post-commit.ps1`, `GitHook.ps1`, `run-hook.ps1` |

---

## Python Scripts

### snake_case Convention

All Python scripts **MUST** follow `snake_case` naming as per [PEP 8](https://peps.python.org/pep-0008/#package-and-module-names):

1. All lowercase letters
2. Words separated by underscores (`_`)
3. Descriptive and concise
4. Extension: `.py`

**Pattern:** `<descriptive_name>.py`

### Naming Rules

1. **Use Lowercase Only**
   - ✅ `csv_to_gpx.py`, `find_duplicate_images.py`
   - ❌ `CSV_to_GPX.py`, `FindDuplicateImages.py`

2. **Separate Words with Underscores**
   - ✅ `cloudconvert_utils.py`, `extract_timeline_locations.py`
   - ❌ `cloudconvert-utils.py`, `extractTimelineLocations.py`

3. **Be Descriptive**
   - ✅ `find_duplicate_images.py`, `google_drive_root_files_delete.py`
   - ❌ `dup.py`, `gdrive.py`

4. **Avoid Abbreviations** (unless standard)
   - ✅ `csv_to_gpx.py` (CSV and GPX are standard)
   - ❌ `csvtogpx.py`, `csv2gpx.py`

### Naming Examples (Python)

| Script Purpose | ✅ Correct Name | ❌ Incorrect Names |
|----------------|----------------|-------------------|
| Convert CSV to GPX | `csv_to_gpx.py` | `csv-to-gpx.py`, `csvToGpx.py`, `CSV2GPX.py` |
| Find duplicate images | `find_duplicate_images.py` | `find-duplicate-images.py`, `FindDuplicates.py`, `dup_img.py` |
| CloudConvert utilities | `cloudconvert_utils.py` | `cloudconvert-utils.py`, `CloudConvertUtils.py`, `cc_util.py` |
| Crop image colors | `crop_colours.py` | `crop-colours.py`, `cropColours.py`, `img_crop.py` |
| Recover file extensions | `recover_extensions.py` | `recover-extensions.py`, `recoverExt.py`, `fix_ext.py` |

---

## Modules

### PowerShell Modules

PowerShell module directories and manifest files use **PascalCase**:

```
src/powershell/module/
├── Videoscreenshot/          # ✅ PascalCase
│   ├── Videoscreenshot.psd1  # ✅ Matches directory
│   ├── Videoscreenshot.psm1  # ✅ Module file
│   └── Public/
│       └── Start-VideoBatch.ps1  # ✅ Verb-Noun functions
└── RandomName/               # ✅ PascalCase
    ├── RandomName.psd1
    └── RandomName.psm1
```

### Python Modules

Python module directories use **snake_case**:

```
src/common/
├── python_logging_framework.py   # ✅ snake_case
└── __init__.py
```

---

## Configuration Files

### Naming Patterns

| File Type | Convention | Example |
|-----------|-----------|---------|
| JSON | kebab-case | `module-deployment-config.json` |
| YAML/YML | kebab-case | `sonarcloud-config.yml` |
| INI/CONF | kebab-case or snake_case | `postgresql.conf`, `app-settings.ini` |
| XML | PascalCase or kebab-case | `PostgreSQL Gnucash Backup.xml` |
| ENV | SCREAMING_SNAKE_CASE (variables) | `.env` |

---

## Validation

### Manual Validation

Check PowerShell script naming:
```powershell
# Find non-compliant PowerShell scripts
Get-ChildItem -Path src/powershell -Filter "*.ps1" -File | Where-Object {
    $_.Name -notmatch '^[A-Z][a-z]+-[A-Z][a-zA-Z0-9]+\.ps1$'
} | Select-Object Name
```

Check Python script naming:
```bash
# Find non-compliant Python scripts
find src/python -name "*.py" -type f | grep -vE '^[a-z_]+\.py$'
```

### Pre-commit Hook

A pre-commit hook validates naming conventions. See `.git/hooks/pre-commit` for implementation.

### CI Validation

The CI pipeline includes a naming convention check. See `.github/workflows/naming-check.yml`.

---

## Quick Reference

### PowerShell Cheat Sheet

✅ **DO:**
- Use approved verbs: `Get-`, `Set-`, `New-`, `Remove-`, `Clear-`, `Invoke-`, etc.
- Use singular nouns: `Remove-File.ps1`, not `Remove-Files.ps1`
- Use PascalCase: `Backup-Database.ps1`
- Be specific: `Clear-PostgreSqlLog.ps1`

❌ **DON'T:**
- Use non-approved verbs: `Delete-`, `Create-`, `Cleanup-`
- Use kebab-case: `backup-database.ps1`
- Use snake_case: `backup_database.ps1`
- Use camelCase: `backupDatabase.ps1`
- Abbreviate excessively: `Bkp-DB.ps1`

### Python Cheat Sheet

✅ **DO:**
- Use all lowercase: `csv_to_gpx.py`
- Separate words with underscores: `find_duplicate_images.py`
- Be descriptive: `google_drive_root_files_delete.py`

❌ **DON'T:**
- Use kebab-case: `csv-to-gpx.py`
- Use PascalCase: `CsvToGpx.py`
- Use camelCase: `csvToGpx.py`
- Abbreviate words: `csv2gpx.py`

---

## Migration Guide

When renaming existing scripts:

1. **Use `git mv`** to preserve history:
   ```bash
   git mv old-name.ps1 New-Name.ps1
   ```

2. **Update all references**:
   - Task Scheduler XML files
   - Documentation (README, CHANGELOG)
   - Other scripts that call the renamed script
   - Configuration files
   - Test files

3. **Document the change**:
   - Add entry to `CHANGELOG.md`
   - Update `docs/RENAME_MAPPING.md`

4. **Test thoroughly**:
   - Verify all scripts still run
   - Check Task Scheduler tasks
   - Run automated tests

---

## Enforcement

### Code Reviews

All pull requests must:
- Follow naming conventions for new scripts
- Update documentation for renamed scripts
- Pass automated naming checks

### Automated Checks

CI/CD pipeline includes:
- Naming convention linter
- Documentation validation
- Reference consistency checks

---

## Examples from Repository

### PowerShell Scripts (Compliant)

- `Backup-GnuCashDatabase.ps1` - Database backup script
- `Clear-PostgreSqlLog.ps1` - Log cleanup script
- `Move-ImageFileToBatch.ps1` - Image file organiser (extension rename + batched move)
- `Get-FileHandle.ps1` - File handle inspector
- `Invoke-PostCommitHook.ps1` - Git post-commit hook
- `Remove-MergedGitBranch.ps1` - Git branch cleanup
- `Restore-FileExtension.ps1` - File extension recovery
- `Show-RandomImage.ps1` - Random image display
- `Test-PostgreSqlConnection.ps1` - Database connection tester

### Python Scripts (Compliant)

- `cloudconvert_utils.py` - CloudConvert API utilities
- `crop_colours.py` - Image border cropping tool
- `csv_to_gpx.py` - CSV to GPX converter
- `drive_space_monitor.py` - Disk space monitoring
- `extract_timeline_locations.py` - Location data extractor
- `find_duplicate_images.py` - Duplicate file detector
- `google_drive_root_files_delete.py` - Google Drive cleanup
- `python_logging_framework.py` - Logging framework
- `recover_extensions.py` - File extension recovery
- `seat_assignment.py` - Seat assignment tool

---

## FAQs

**Q: Can I use custom verbs for PowerShell scripts?**
A: No. Always use [approved PowerShell verbs](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands). If you think you need a custom verb, there's likely an approved verb that fits.

**Q: What if my script does multiple things?**
A: Choose the primary action. For example, a script that backs up a database and emails a report should be named `Backup-Database.ps1` with the email as a secondary feature.

**Q: Can Python scripts use PascalCase?**
A: No. Python modules must use `snake_case` per PEP 8. Only classes inside Python files use PascalCase.

**Q: What about acronyms in PowerShell?**
A: Treat well-known acronyms as single words: `Get-HttpResponse.ps1`, `Test-SqlConnection.ps1`, `Export-CsvFile.ps1`.

**Q: Can I abbreviate long names?**
A: Avoid abbreviations except for universally understood ones (SQL, HTTP, CSV, GPX, etc.). Clarity is more important than brevity.

---

## References

### Official Documentation

- [PowerShell Approved Verbs](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- [PowerShell Cmdlet Naming Rules](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-naming-rules)
- [PEP 8 – Style Guide for Python Code](https://peps.python.org/pep-0008/)
- [PEP 8 – Package and Module Names](https://peps.python.org/pep-0008/#package-and-module-names)

### Repository Documents

- [RENAME_MAPPING.md](../RENAME_MAPPING.md) - Complete list of script renames
- [CHANGELOG.md](../../CHANGELOG.md) - Repository change log
- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution guidelines

---

## Version History

- **v1.0.0** (2025-11-18) - Initial naming conventions documentation
  - Defined PowerShell Verb-Noun PascalCase standard
  - Defined Python snake_case standard
  - Added examples, validation methods, and migration guide
  - Created as part of Issue #454 (Standardize Naming Conventions)
