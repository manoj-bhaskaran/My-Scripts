# Database & Backup Scripts

Scripts for automated database backups and synchronization.

## Scripts

### Backup Scripts
- **Backup-GnuCashDatabase.ps1** - PostgreSQL backup for GnuCash database (structured logging + object output)
- **Backup-JobSchedulerDatabase.ps1** - Job scheduler database backup automation
- **Backup-TimelineDatabase.ps1** - Timeline data database backup (structured logging + object output)
- **Backup-PostgreSqlCommon.ps1** - Common PostgreSQL backup functions

### Synchronization Scripts
- **Sync-MacriumBackups.ps1** - Macrium backup synchronization between local and remote storage with auto-resume capability
- **scripts/Sync-Directory.ps1** - File synchronization utility that emits capturable summaries for automation

### Task Registration Scripts
- **Register-SyncMacriumBackupsTask.ps1** - Automated Windows Task Scheduler registration for Sync-MacriumBackups startup execution

## Dependencies

### PowerShell Modules
- **PostgresBackup** (`src/powershell/modules/Database/PostgresBackup/`) - Provides core PostgreSQL backup functionality
- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging

### External Tools
- PostgreSQL client tools (pg_dump)
- PowerShell 5.1 or later

## Scheduling

These scripts are configured to run automatically via Windows Task Scheduler.

### Automated Task Registration

For **Sync-MacriumBackups.ps1**, use the automated registration script for quick setup:

```powershell
# Register task to run at startup (requires Administrator privileges)
# By default, creates task in "\My Scheduled Tasks\" folder
.\Register-SyncMacriumBackupsTask.ps1

# Register task to run as SYSTEM account
.\Register-SyncMacriumBackupsTask.ps1 -RunAsUser "SYSTEM"

# Register task in a custom Task Scheduler folder
.\Register-SyncMacriumBackupsTask.ps1 -TaskPath "\Backup Tasks\"

# Register task in a nested folder structure (auto-creates all levels)
.\Register-SyncMacriumBackupsTask.ps1 -TaskPath "\Backups\Nightly\"

# Register task in the root Task Scheduler Library
.\Register-SyncMacriumBackupsTask.ps1 -TaskPath "\"

# Remove the scheduled task
.\Register-SyncMacriumBackupsTask.ps1 -Remove

# Remove task from custom folder
.\Register-SyncMacriumBackupsTask.ps1 -Remove -TaskPath "\Backup Tasks\"

# Use custom script path
.\Register-SyncMacriumBackupsTask.ps1 -ScriptPath "C:\Custom\Path\Sync-MacriumBackups.ps1"
```

**Features of the registered task:**
- Organized in custom Task Scheduler folder (default: "My Scheduled Tasks")
- Runs automatically at system startup and user logon (service accounts: startup only)
- Executes with `-AutoResume` flag for intelligent restart behavior
- Waits for network availability before starting
- Automatically retries up to 3 times (every 15 minutes) on failure
- Runs with highest privileges (Administrator)
- Allows execution on battery power
- Supports both regular user accounts and service accounts (SYSTEM, LOCAL SERVICE, NETWORK SERVICE)

### Manual Task Definitions

Pre-configured task XML definitions are located in:
- `config/tasks/PostgreSQL Gnucash Backup.xml`
- `config/tasks/PostgreSQL job_scheduler Backup.xml`
- `config/tasks/PostgreSQL timeline_data Backup.xml`
- `config/tasks/Sync Macrium Backups.xml`

## Configuration

Database connection parameters are typically configured within each script or read from environment variables. Check individual scripts for specific configuration requirements.

## Logging and automation

- All backup utilities use the PowerShell Logging Framework and write logs to the standard logs directory as defined in the logging specification.
- Backup launcher scripts emit structured `PSCustomObject` summaries via `Write-Output` so task schedulers and automation can capture results programmatically.
- `scripts/Sync-Directory.ps1` returns a plan (counts + relative paths) when run with `-PreviewOnly` and a detailed action log after execution.
