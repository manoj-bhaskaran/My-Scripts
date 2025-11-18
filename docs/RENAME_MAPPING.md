# Script Rename Mapping (v2.0.0)

**Document Version:** 2.0.0
**Date:** 2025-11-18
**Issue:** #454

This document details all script renames performed to standardize naming conventions across the My-Scripts repository. All renames preserve git history using `git mv`.

---

## Summary

- **PowerShell Scripts Renamed:** 19
- **Python Scripts Renamed:** 2
- **Total Files Affected:** 21

---

## PowerShell Scripts (Verb-Noun PascalCase Convention)

All PowerShell script names must follow the `Verb-Noun` pattern where:
- **Verb** must be from the [PowerShell Approved Verbs list](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- **Noun** should be singular and descriptive
- Both Verb and Noun use PascalCase

| # | Old Name | New Name | Approved Verb | Justification |
|---|----------|----------|---------------|---------------|
| 1 | `logCleanup.ps1` | `Clear-PostgreSqlLog.ps1` | `Clear` | Uses approved verb `Clear` for removing old log files. Specifies PostgreSQL in noun for clarity. |
| 2 | `cleanup-git-branches.ps1` | `Remove-MergedGitBranch.ps1` | `Remove` | Uses approved verb `Remove` instead of non-standard "cleanup". Singular noun `Branch` per PowerShell conventions. |
| 3 | `picconvert.ps1` | `Convert-ImageFile.ps1` | `Convert` | Uses approved verb `Convert` for file conversion. Generic noun `ImageFile` as it handles multiple image types. |
| 4 | `post-commit-my-scripts.ps1` | `Invoke-PostCommitHook.ps1` | `Invoke` | Uses approved verb `Invoke` for executing hook scripts. Noun clearly identifies it as a Git post-commit hook. |
| 5 | `post-merge-my-scripts.ps1` | `Invoke-PostMergeHook.ps1` | `Invoke` | Uses approved verb `Invoke` for executing hook scripts. Noun clearly identifies it as a Git post-merge hook. |
| 6 | `DeleteOldDownloads.ps1` | `Remove-OldDownload.ps1` | `Remove` | `Delete` is not an approved verb. Uses `Remove` instead. Singular noun `Download` per PowerShell conventions. |
| 7 | `scrubname.ps1` | `Remove-FilenameString.ps1` | `Remove` | Uses approved verb `Remove` for removing strings from filenames. Noun describes what is being removed. |
| 8 | `videoscreenshot.ps1` | `Show-VideoscreenshotDeprecation.ps1` | `Show` | Legacy wrapper showing deprecation message. Uses `Show` verb for displaying information to user. |
| 9 | `job_scheduler_pg_backup.ps1` | `Backup-JobSchedulerDatabase.ps1` | `Backup` | Uses approved verb `Backup`. Noun identifies the specific database being backed up. |
| 10 | `purge_logs.ps1` | `Clear-LogFile.ps1` | `Clear` | Uses approved verb `Clear` for purging/truncating log files. Singular noun `LogFile`. |
| 11 | `recover-extensions.ps1` | `Restore-FileExtension.ps1` | `Restore` | Uses approved verb `Restore` for recovering file extensions. Converted kebab-case to PascalCase. |
| 12 | `handle.ps1` | `Get-FileHandle.ps1` | `Get` | Uses approved verb `Get` for retrieving file handle information using Sysinternals Handle.exe. |
| 13 | `pgconnect.ps1` | `Test-PostgreSqlConnection.ps1` | `Test` | Uses approved verb `Test` for testing database connections. Noun specifies PostgreSQL connection testing. |
| 14 | `WLANsvc.ps1` | `Restart-WlanService.ps1` | `Restart` | Uses approved verb `Restart` for restarting the WLAN service. Proper PascalCase for service name. |
| 15 | `cloudconvert_driver.ps1` | `Invoke-CloudConvert.ps1` | `Invoke` | Uses approved verb `Invoke` for calling CloudConvert API via Python wrapper. |
| 16 | `SelObj.ps1` | `Show-RandomImage.ps1` | `Show` | Uses approved verb `Show` for displaying a random image file. Noun describes what is shown. |
| 17 | `gnucash_pg_backup.ps1` | `Backup-GnuCashDatabase.ps1` | `Backup` | Uses approved verb `Backup`. Noun identifies GnuCash database. |
| 18 | `pg_backup_common.ps1` | `Backup-PostgreSqlCommon.ps1` | `Backup` | Uses approved verb `Backup`. Identifies as common PostgreSQL backup utilities. |
| 19 | `timeline_data_pg_backup.ps1` | `Backup-TimelineDatabase.ps1` | `Backup` | Uses approved verb `Backup`. Noun identifies Timeline database. |

---

## Python Scripts (snake_case Convention)

All Python script names must follow `snake_case` convention per [PEP 8](https://peps.python.org/pep-0008/#package-and-module-names):
- All lowercase
- Words separated by underscores
- Descriptive and concise

| # | Old Name | New Name | Reason |
|---|----------|----------|--------|
| 1 | `csv-to-gpx.py` | `csv_to_gpx.py` | Converts kebab-case to snake_case for PEP 8 compliance. |
| 2 | `find-duplicate-images.py` | `find_duplicate_images.py` | Converts kebab-case to snake_case for PEP 8 compliance. |

---

## Files Already Compliant

The following scripts already follow proper naming conventions and require **no changes**:

### PowerShell (Verb-Noun PascalCase)
- `Copy-AndroidFiles.ps1`
- `Remove-DuplicateFiles.ps1`
- `Expand-ZipsAndClean.ps1`
- `Update-ScheduledTaskScriptPaths.ps1`
- `Sync-MacriumBackups.ps1`
- `Invoke-SystemHealthCheck.ps1`
- `Install-SystemHealthCheckTask.ps1`
- `ConvertTo-Jpeg.ps1`
- `SyncRepoToTarget.ps1`
- `Remove-EmptyFolders.ps1`
- `WireLessAdapter.ps1`
- `FileDistributor.ps1`
- `ClearOldRecycleBinItems.ps1`

### Python (snake_case)
- `cloudconvert_utils.py`
- `crop_colours.py`
- `recover_extensions.py`
- `extract_timeline_locations.py`
- `google_drive_root_files_delete.py`
- `seat_assignment.py`
- `drive_space_monitor.py`
- `gdrive_recover.py`
- `validators.py`

---

## PowerShell Approved Verbs Reference

The following approved verbs were used in these renames:

| Verb | Category | Purpose | Used In |
|------|----------|---------|---------|
| `Backup` | Data | Create a backup copy | Database backup scripts |
| `Clear` | Common | Remove or reset content | Log cleanup scripts |
| `Convert` | Data | Change format | Image conversion |
| `Get` | Common | Retrieve information | File handle retrieval |
| `Invoke` | Lifecycle | Execute or run | Git hooks, API calls |
| `Remove` | Common | Delete or eliminate | File/branch deletion |
| `Restart` | Lifecycle | Stop and start | Service restart |
| `Restore` | Data | Recover to original state | File extension recovery |
| `Show` | Common | Display to user | Deprecation messages, random images |
| `Test` | Diagnostic | Verify or validate | Connection testing |

Complete list of approved verbs: [Microsoft Documentation](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)

---

## Breaking Changes

⚠️ **This is a BREAKING CHANGE** for:
1. **Windows Task Scheduler** tasks referencing old script names
2. **Git hooks** using old names
3. **External scripts** calling renamed files
4. **Hardcoded paths** in configuration files or other scripts

---

## Migration Guide

### For Windows Task Scheduler

Search and update task definitions in `Windows Task Scheduler/` directory:

```powershell
# Example: Update task XML files
Get-ChildItem "Windows Task Scheduler" -Filter "*.xml" -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    # Replace old names with new names
    $content = $content -replace 'cleanup-git-branches\.ps1', 'Remove-MergedGitBranch.ps1'
    $content = $content -replace 'logCleanup\.ps1', 'Clear-PostgreSqlLog.ps1'
    # ... add more replacements
    Set-Content $_.FullName $content
}
```

### For Git Hooks

Update the following Git hook files if they reference renamed scripts:
- `.git/hooks/post-commit` (references `Invoke-PostCommitHook.ps1`)
- `.git/hooks/post-merge` (references `Invoke-PostMergeHook.ps1`)

### For Configuration Files

Check and update:
- `config/module-deployment-config.txt`
- Any `.json`, `.yml`, or `.xml` configuration files
- README files and documentation

---

## Validation

After renaming, verify:

1. ✅ All file renames completed successfully
2. ✅ Git history preserved for all files
3. ✅ All references updated in documentation
4. ✅ All references updated in configuration files
5. ✅ Windows Task Scheduler tasks updated (if applicable)
6. ✅ Git hooks updated and functional
7. ✅ No broken imports or dead references

---

## Version History

- **v2.0.0** (2025-11-18) - Initial standardization of naming conventions across repository
  - Renamed 19 PowerShell scripts to Verb-Noun PascalCase
  - Renamed 2 Python scripts to snake_case
  - All renames preserve git history using `git mv`

---

## References

- [PowerShell Approved Verbs](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- [PowerShell Cmdlet Naming Rules](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-naming-rules)
- [PEP 8 – Style Guide for Python Code](https://peps.python.org/pep-0008/)
- [Issue #454: Standardize Naming Conventions Across Repository](https://github.com/manoj-bhaskaran/My-Scripts/issues/454)
