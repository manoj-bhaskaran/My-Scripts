# Database & Backup Scripts

Scripts for automated database backups and synchronization.

## Scripts

- **Backup-GnuCashDatabase.ps1** - PostgreSQL backup for GnuCash database
- **Backup-JobSchedulerDatabase.ps1** - Job scheduler database backup automation
- **Backup-TimelineDatabase.ps1** - Timeline data database backup
- **Backup-PostgreSqlCommon.ps1** - Common PostgreSQL backup functions
- **Sync-MacriumBackups.ps1** - Macrium backup synchronization between local and remote storage

## Dependencies

### PowerShell Modules
- **PostgresBackup** (`src/powershell/modules/Database/PostgresBackup/`) - Provides core PostgreSQL backup functionality
- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging

### External Tools
- PostgreSQL client tools (pg_dump)
- PowerShell 5.1 or later

## Scheduling

These scripts are configured to run automatically via Windows Task Scheduler. Task definitions are located in:
- `config/tasks/PostgreSQL Gnucash Backup.xml`
- `config/tasks/PostgreSQL job_scheduler Backup.xml`
- `config/tasks/PostgreSQL timeline_data Backup.xml`
- `config/tasks/Sync Macrium Backups.xml`

## Configuration

Database connection parameters are typically configured within each script or read from environment variables. Check individual scripts for specific configuration requirements.

## Logging

All scripts use the PowerShell Logging Framework and write logs to the standard logs directory as defined in the logging specification.
