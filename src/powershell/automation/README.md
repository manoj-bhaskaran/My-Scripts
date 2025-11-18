# Automation & Utility Scripts

General-purpose automation scripts and utilities.

## Scripts

- **Update-ScheduledTaskScriptPaths.ps1** - Updates Windows Task Scheduler task definitions with new script paths
- **Test-PostgreSqlConnection.ps1** - Tests PostgreSQL database connectivity and configuration

## Dependencies

### PowerShell Modules
- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging

### External Tools
- PowerShell 5.1 or later
- PostgreSQL client libraries (for database testing)
- Administrator privileges (for Task Scheduler operations)

## Use Cases

### Task Scheduler Management

The `Update-ScheduledTaskScriptPaths.ps1` script is particularly useful when:
- Reorganizing repository structure
- Moving scripts to new locations
- Bulk updating task definitions

### Database Testing

The `Test-PostgreSqlConnection.ps1` script helps verify:
- Database connectivity
- Authentication configuration
- Network accessibility
- PostgreSQL service status

## Logging

All scripts use the PowerShell Logging Framework and write logs to the standard logs directory.
