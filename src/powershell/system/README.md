# System Maintenance Scripts

Scripts for system cleanup, monitoring, and maintenance tasks.

## Scripts

### Cleanup Scripts
- **ClearOldRecycleBinItems.ps1** - Removes old items from the Recycle Bin
- **Remove-OldDownload.ps1** - Cleans up old files from Downloads folder
- **Remove-DuplicateFiles.ps1** - Identifies and removes duplicate files
- **Remove-EmptyFolders.ps1** - Removes empty directories from specified paths
- **Clear-LogFile.ps1** - Manages and purges log files
- **Clear-PostgreSqlLog.ps1** - PostgreSQL log cleanup and rotation

### Monitoring & Health
- **Invoke-SystemHealthCheck.ps1** - Comprehensive system health monitoring
- **Install-SystemHealthCheckTask.ps1** - Installs scheduled task for health checks

### Network
- **Restart-WlanService.ps1** - Restarts WLAN service for troubleshooting
- **WireLessAdapter.ps1** - Wireless adapter management utilities

## Dependencies

### PowerShell Modules
- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging
- **PurgeLogs** (`src/powershell/modules/Core/Logging/`) - Log purging functionality

### Permissions
Many scripts require administrator privileges for system-level operations.

## Scheduling

Several scripts are configured to run automatically via Windows Task Scheduler:
- `config/tasks/Clear Old Recycle Bin Items.xml`
- `config/tasks/Delete Old Downloads.xml`
- `config/tasks/Monthly System Health Check.xml`
- `config/tasks/Postgres Log Cleanup.xml`

## Configuration

Scripts typically use built-in defaults but can be configured via parameters. Check individual scripts for available options.

## Logging

All scripts use the PowerShell Logging Framework and write logs to the standard logs directory.
