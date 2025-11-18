# Folder Migration Plan - Issue #457

This document maps the reorganization of the My-Scripts repository from a language-only structure to a domain-based structure within each language folder.

**Migration Date**: 2025-11-18
**Issue**: #457 - Reorganize Folder Structure by Domain
**Branch**: claude/reorganize-by-domain-01XCWnT9D9tkEuhWcbq6Arc4

## Migration Principles

1. **Preserve Git History**: All moves use `git mv` to maintain file history
2. **Domain-Based Organization**: Scripts grouped by functional domain within language folders
3. **Consistent Naming**: Following PowerShell verb-noun convention where applicable
4. **Module Consolidation**: Shared modules moved to categorized module structure

---

## PowerShell Scripts Migration

### Backup Domain (`src/powershell/backup/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/Backup-GnuCashDatabase.ps1` | `src/powershell/backup/Backup-GnuCashDatabase.ps1` | GnuCash PostgreSQL backup |
| `src/powershell/Backup-JobSchedulerDatabase.ps1` | `src/powershell/backup/Backup-JobSchedulerDatabase.ps1` | Job scheduler database backup |
| `src/powershell/Backup-TimelineDatabase.ps1` | `src/powershell/backup/Backup-TimelineDatabase.ps1` | Timeline database backup |
| `src/powershell/Backup-PostgreSqlCommon.ps1` | `src/powershell/backup/Backup-PostgreSqlCommon.ps1` | Common PostgreSQL backup functions |
| `src/powershell/Sync-MacriumBackups.ps1` | `src/powershell/backup/Sync-MacriumBackups.ps1` | Macrium backup synchronization |

### File Management Domain (`src/powershell/file-management/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/FileDistributor.ps1` | `src/powershell/file-management/FileDistributor.ps1` | File distribution utility |
| `src/powershell/Copy-AndroidFiles.ps1` | `src/powershell/file-management/Copy-AndroidFiles.ps1` | Android file copying |
| `src/powershell/Expand-ZipsAndClean.ps1` | `src/powershell/file-management/Expand-ZipsAndClean.ps1` | ZIP extraction and cleanup |
| `src/powershell/SyncRepoToTarget.ps1` | `src/powershell/file-management/SyncRepoToTarget.ps1` | Repository synchronization |
| `src/powershell/Get-FileHandle.ps1` | `src/powershell/file-management/Get-FileHandle.ps1` | File handle inspection |
| `src/powershell/Restore-FileExtension.ps1` | `src/powershell/file-management/Restore-FileExtension.ps1` | File extension restoration |
| `src/powershell/Remove-FilenameString.ps1` | `src/powershell/file-management/Remove-FilenameString.ps1` | Filename string removal |

### System Maintenance Domain (`src/powershell/system/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/ClearOldRecycleBinItems.ps1` | `src/powershell/system/ClearOldRecycleBinItems.ps1` | Recycle bin cleanup |
| `src/powershell/Remove-OldDownload.ps1` | `src/powershell/system/Remove-OldDownload.ps1` | Old downloads cleanup |
| `src/powershell/Remove-DuplicateFiles.ps1` | `src/powershell/system/Remove-DuplicateFiles.ps1` | Duplicate file removal |
| `src/powershell/Remove-EmptyFolders.ps1` | `src/powershell/system/Remove-EmptyFolders.ps1` | Empty folder removal |
| `src/powershell/Clear-LogFile.ps1` | `src/powershell/system/Clear-LogFile.ps1` | Log file cleanup |
| `src/powershell/Clear-PostgreSqlLog.ps1` | `src/powershell/system/Clear-PostgreSqlLog.ps1` | PostgreSQL log cleanup |
| `src/powershell/Invoke-SystemHealthCheck.ps1` | `src/powershell/system/Invoke-SystemHealthCheck.ps1` | System health monitoring |
| `src/powershell/Install-SystemHealthCheckTask.ps1` | `src/powershell/system/Install-SystemHealthCheckTask.ps1` | Health check task installer |
| `src/powershell/Restart-WlanService.ps1` | `src/powershell/system/Restart-WlanService.ps1` | WLAN service restart |
| `src/powershell/WireLessAdapter.ps1` | `src/powershell/system/WireLessAdapter.ps1` | Wireless adapter management |

### Git Operations Domain (`src/powershell/git/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/Remove-MergedGitBranch.ps1` | `src/powershell/git/Remove-MergedGitBranch.ps1` | Merged branch cleanup |
| `src/powershell/Invoke-PostCommitHook.ps1` | `src/powershell/git/Invoke-PostCommitHook.ps1` | Post-commit hook |
| `src/powershell/Invoke-PostMergeHook.ps1` | `src/powershell/git/Invoke-PostMergeHook.ps1` | Post-merge hook |

### Media Processing Domain (`src/powershell/media/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/ConvertTo-Jpeg.ps1` | `src/powershell/media/ConvertTo-Jpeg.ps1` | JPEG conversion |
| `src/powershell/Convert-ImageFile.ps1` | `src/powershell/media/Convert-ImageFile.ps1` | Image format conversion |
| `src/powershell/Show-RandomImage.ps1` | `src/powershell/media/Show-RandomImage.ps1` | Random image display |
| `src/powershell/Show-VideoscreenshotDeprecation.ps1` | `src/powershell/media/Show-VideoscreenshotDeprecation.ps1` | Videoscreenshot deprecation notice |

### Cloud Services Domain (`src/powershell/cloud/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/Invoke-CloudConvert.ps1` | `src/powershell/cloud/Invoke-CloudConvert.ps1` | CloudConvert API integration |

### Automation/Utilities Domain (`src/powershell/automation/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/Update-ScheduledTaskScriptPaths.ps1` | `src/powershell/automation/Update-ScheduledTaskScriptPaths.ps1` | Task scheduler path updater |
| `src/powershell/Test-PostgreSqlConnection.ps1` | `src/powershell/automation/Test-PostgreSqlConnection.ps1` | PostgreSQL connection tester |

---

## PowerShell Modules Migration

### Core Modules (`src/powershell/modules/Core/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/common/PowerShellLoggingFramework.psm1` | `src/powershell/modules/Core/Logging/PowerShellLoggingFramework.psm1` | Logging framework module |
| `src/common/PowerShellLoggingFramework.psd1` | `src/powershell/modules/Core/Logging/PowerShellLoggingFramework.psd1` | Logging framework manifest |
| `src/common/PurgeLogs.psm1` | `src/powershell/modules/Core/Logging/PurgeLogs.psm1` | Log purging module |
| `src/common/PurgeLogs.psd1` | `src/powershell/modules/Core/Logging/PurgeLogs.psd1` | Log purging manifest |

### Database Modules (`src/powershell/modules/Database/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/common/PostgresBackup.psm1` | `src/powershell/modules/Database/PostgresBackup/PostgresBackup.psm1` | PostgreSQL backup module |
| `src/common/PostgresBackup.psd1` | `src/powershell/modules/Database/PostgresBackup/PostgresBackup.psd1` | PostgreSQL backup manifest |

### Utility Modules (`src/powershell/modules/Utilities/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/module/RandomName/` | `src/powershell/modules/Utilities/RandomName/` | Random name generator module |

### Media Modules (`src/powershell/modules/Media/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/powershell/module/Videoscreenshot/` | `src/powershell/modules/Media/Videoscreenshot/` | Video screenshot module |

---

## Python Scripts Migration

### Data Processing Domain (`src/python/data/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/python/extract_timeline_locations.py` | `src/python/data/extract_timeline_locations.py` | Timeline location extraction |
| `src/python/csv_to_gpx.py` | `src/python/data/csv_to_gpx.py` | CSV to GPX conversion |
| `src/python/validators.py` | `src/python/data/validators.py` | Data validators |
| `src/python/seat_assignment.py` | `src/python/data/seat_assignment.py` | Seat assignment utility |

### Cloud Services Domain (`src/python/cloud/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/python/gdrive_recover.py` | `src/python/cloud/gdrive_recover.py` | Google Drive recovery |
| `src/python/google_drive_root_files_delete.py` | `src/python/cloud/google_drive_root_files_delete.py` | Drive root cleanup |
| `src/python/drive_space_monitor.py` | `src/python/cloud/drive_space_monitor.py` | Drive space monitoring |
| `src/python/cloudconvert_utils.py` | `src/python/cloud/cloudconvert_utils.py` | CloudConvert utilities |

### Media Processing Domain (`src/python/media/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/python/find_duplicate_images.py` | `src/python/media/find_duplicate_images.py` | Duplicate image finder |
| `src/python/crop_colours.py` | `src/python/media/crop_colours.py` | Image color cropping |
| `src/python/recover_extensions.py` | `src/python/media/recover_extensions.py` | File extension recovery |

---

## Python Modules Migration

### Logging Module (`src/python/modules/logging/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/common/python_logging_framework.py` | `src/python/modules/logging/python_logging_framework.py` | Python logging framework |
| `src/common/python_logging_framework.egg-info/` | `src/python/modules/logging/python_logging_framework.egg-info/` | Package info |
| `src/common/__init__.py` | `src/python/modules/logging/__init__.py` | Module init (copy to logging) |

### Authentication Module (`src/python/modules/auth/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/common/google_drive_auth.py` | `src/python/modules/auth/google_drive_auth.py` | Google Drive authentication |
| `src/common/elevation.py` | `src/python/modules/auth/elevation.py` | Privilege elevation utilities |
| `src/common/__init__.py` | `src/python/modules/auth/__init__.py` | Module init (copy to auth) |

---

## SQL Scripts Migration

### GnuCash Database (`src/sql/gnucash/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `src/sql/gnucash_db/gnucash_hide_zero_balance_accts.sql` | `src/sql/gnucash/gnucash_hide_zero_balance_accts.sql` | Hide zero balance accounts |
| `src/sql/gnucash_db/gnucash_unhide_zero_balance_accts.sql` | `src/sql/gnucash/gnucash_unhide_zero_balance_accts.sql` | Unhide zero balance accounts |

### Timeline Database (`src/sql/timeline/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `timeline_data/database/create_database.sql` | `src/sql/timeline/create_database.sql` | Database creation |
| `timeline_data/postgis/create_postgis_extension.sql` | `src/sql/timeline/create_postgis_extension.sql` | PostGIS extension |
| `timeline_data/schema/timeline.sql` | `src/sql/timeline/schema_timeline.sql` | Timeline schema |
| `timeline_data/tables/control.sql` | `src/sql/timeline/table_control.sql` | Control table |
| `timeline_data/tables/locations.sql` | `src/sql/timeline/table_locations.sql` | Locations table |
| `timeline_data/users/backup_user.sql` | `src/sql/timeline/user_backup.sql` | Backup user |
| `timeline_data/users/timeline_writer.sql` | `src/sql/timeline/user_timeline_writer.sql` | Timeline writer user |

---

## Configuration Files Migration

### Task Scheduler Configurations (`config/tasks/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `Windows Task Scheduler/.gitattributes` | `config/tasks/.gitattributes` | Git attributes |
| `Windows Task Scheduler/Clear Old Recycle Bin Items.xml` | `config/tasks/Clear Old Recycle Bin Items.xml` | Recycle bin task |
| `Windows Task Scheduler/Delete Old Downloads.xml` | `config/tasks/Delete Old Downloads.xml` | Downloads cleanup task |
| `Windows Task Scheduler/Drive Space Monitor.xml` | `config/tasks/Drive Space Monitor.xml` | Drive monitor task |
| `Windows Task Scheduler/Monthly System Health Check.xml` | `config/tasks/Monthly System Health Check.xml` | Health check task |
| `Windows Task Scheduler/PostgreSQL Gnucash Backup.xml` | `config/tasks/PostgreSQL Gnucash Backup.xml` | GnuCash backup task |
| `Windows Task Scheduler/PostgreSQL job_scheduler Backup.xml` | `config/tasks/PostgreSQL job_scheduler Backup.xml` | Job scheduler backup task |
| `Windows Task Scheduler/PostgreSQL timeline_data Backup.xml` | `config/tasks/PostgreSQL timeline_data Backup.xml` | Timeline backup task |
| `Windows Task Scheduler/Postgres Log Cleanup.xml` | `config/tasks/Postgres Log Cleanup.xml` | Log cleanup task |
| `Windows Task Scheduler/Sync Macrium Backups.xml` | `config/tasks/Sync Macrium Backups.xml` | Macrium sync task |

### Module Configurations (`config/modules/`)

| Old Path | New Path | Description |
|----------|----------|-------------|
| `config/module-deployment-config.txt` | `config/modules/deployment.txt` | Module deployment config |

---

## Shell Scripts (No Change)

These remain in their current locations as there are few enough files:

- `src/sh/create_github_issues.sh` (unchanged)
- `src/batch/RunDeleteOldDownloads.bat` (unchanged)
- `src/batch/printcancel.cmd` (unchanged)

---

## Post-Migration Updates Required

### 1. Import Path Updates

**PowerShell Scripts** - Update dot-sourcing and Import-Module statements:
- Old: `. "$PSScriptRoot/../../common/PostgresBackup.psm1"`
- New: `. "$PSScriptRoot/../modules/Database/PostgresBackup/PostgresBackup.psm1"`

**Python Scripts** - Update import statements:
- Old: `from src.common.python_logging_framework import ...`
- New: `from src.python.modules.logging.python_logging_framework import ...`

### 2. Task Scheduler XML Updates

Update `<Command>` and `<Arguments>` paths in all XML files in `config/tasks/`:
- Old: `<Arguments>-File "C:\Path\To\src\powershell\Backup-GnuCashDatabase.ps1"`
- New: `<Arguments>-File "C:\Path\To\src\powershell\backup\Backup-GnuCashDatabase.ps1"`

### 3. Git Hooks Updates

Update paths in:
- `.git/hooks/post-commit` → `src/powershell/git/Invoke-PostCommitHook.ps1`
- `.git/hooks/post-merge` → `src/powershell/git/Invoke-PostMergeHook.ps1`

### 4. Module Deployment Configuration

Update `config/modules/deployment.txt` with new module paths.

### 5. CI/CD Workflow Updates

Check and update `.github/workflows/sonarcloud.yml` if it references specific script paths.

---

## Validation Checklist

- [ ] All 38 PowerShell scripts moved
- [ ] All 11 Python scripts moved
- [ ] All 9 SQL files moved (2 gnucash + 7 timeline)
- [ ] All 6 PowerShell modules moved
- [ ] All 10 Task Scheduler XML files moved
- [ ] Configuration files reorganized
- [ ] Git history preserved (verify with `git log --follow <new-path>`)
- [ ] All imports updated and tested
- [ ] Task scheduler tasks updated
- [ ] Git hooks updated
- [ ] Module deployment config updated
- [ ] Per-folder README files created (minimum 7)
- [ ] Root README.md updated
- [ ] No broken references
- [ ] All scripts functional

---

## Rollback Plan

If migration needs to be reverted:

```bash
git reset --hard <commit-before-migration>
git clean -fd
```

Or cherry-pick specific commits to undo incrementally.

---

**Migration Status**: Planned
**Last Updated**: 2025-11-18
