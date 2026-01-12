# Lift Simulator Database Backup Setup

This document provides setup instructions for the automated backup of the `lift_simulator` PostgreSQL database.

## Overview

- **Database**: `lift_simulator`
- **Backup Script**: `Backup-LiftSimulatorDatabase.ps1`
- **Schedule**: Daily at 07:30 UTC (±1 hour random delay)
- **Retention Policy**: 90 days (minimum 3 backups always retained)
- **Backup Location**: `D:\pgbackup\lift_simulator\`
- **Logs Location**: `D:\pgbackup\lift_simulator\logs\`

## Prerequisites

### 1. PostgreSQL Installation
- PostgreSQL must be installed and running (currently configured for PostgreSQL 17)
- Service name: `postgresql-x64-17`
- Default path: `D:\Program Files\PostgreSQL\17\bin\pg_dump.exe`

### 2. Backup User Requirements

The `backup_user` PostgreSQL account must have sufficient privileges to back up the `lift_simulator` database.

#### Check if Backup User Exists

Connect to PostgreSQL as a superuser and run:

```sql
-- Check if backup_user exists
SELECT usename, usesuper, usecreatedb
FROM pg_user
WHERE usename = 'backup_user';
```

If the user doesn't exist, create it:

```sql
-- Create backup_user (if not exists)
CREATE USER backup_user WITH PASSWORD 'your_secure_password';
```

#### Verify Database Privileges

Run these queries to verify the `backup_user` has the necessary privileges:

```sql
-- Check database-level privileges for lift_simulator
SELECT
    datname AS database,
    has_database_privilege('backup_user', datname, 'CONNECT') AS can_connect
FROM pg_database
WHERE datname = 'lift_simulator';

-- Check if backup_user can read all tables in lift_simulator
\c lift_simulator
SELECT
    schemaname,
    tablename,
    has_table_privilege('backup_user', schemaname || '.' || tablename, 'SELECT') AS can_read
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;
```

#### Grant Required Privileges

If the backup user lacks privileges, grant them as follows:

```sql
-- Connect to lift_simulator database
\c lift_simulator

-- Grant CONNECT privilege on database
GRANT CONNECT ON DATABASE lift_simulator TO backup_user;

-- Grant USAGE on schemas (adjust schema names as needed)
GRANT USAGE ON SCHEMA public TO backup_user;

-- Grant SELECT on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;

-- Grant SELECT on all future tables (recommended)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO backup_user;

-- Grant SELECT on all sequences (if needed for complete backup)
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO backup_user;

-- If you have additional schemas, repeat for each:
-- GRANT USAGE ON SCHEMA schema_name TO backup_user;
-- GRANT SELECT ON ALL TABLES IN SCHEMA schema_name TO backup_user;
```

#### Verify Privileges Again

After granting privileges, verify with:

```sql
-- Verify backup_user can connect
SELECT has_database_privilege('backup_user', 'lift_simulator', 'CONNECT');

-- Test actual read access to a table (replace 'your_table' with an actual table name)
\c lift_simulator
SET ROLE backup_user;
SELECT COUNT(*) FROM your_table;
RESET ROLE;
```

### 3. Authentication Setup

#### Option A: .pgpass File (Recommended)

Create or edit the `.pgpass` file for secure password storage:

**Location**: `%APPDATA%\postgresql\pgpass.conf` (Windows)

**Format**:
```
localhost:5432:lift_simulator:backup_user:your_password_here
```

**File Permissions** (Important):
- On Windows, restrict access to the current user only
- Remove permissions for "Everyone", "Users", and "Authenticated Users" groups
- Right-click file → Properties → Security → Advanced → Remove unnecessary permissions

**PowerShell command to set proper permissions**:
```powershell
$pgpassFile = Join-Path $env:APPDATA 'postgresql\pgpass.conf'
$acl = Get-Acl $pgpassFile
# Remove inheritance
$acl.SetAccessRuleProtection($true, $false)
# Remove all existing rules
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
# Add current user with full control
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, 'FullControl', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl -Path $pgpassFile -AclObject $acl
```

#### Option B: Environment Variable (Alternative)

Set a custom PGPASSFILE location:

```powershell
$env:PGPASSFILE = "C:\secure\location\pgpass.conf"
```

**Note**: The backup script checks for `$env:PGPASSFILE` first, then falls back to the default location.

### 4. Test Connection

Verify the backup user can connect:

```powershell
# Set PGPASSFILE if using custom location
# $env:PGPASSFILE = "C:\path\to\pgpass.conf"

# Test connection (should not prompt for password if .pgpass is correct)
& "D:\Program Files\PostgreSQL\17\bin\psql.exe" -h localhost -U backup_user -d lift_simulator -c "SELECT version();"
```

If this prompts for a password, your `.pgpass` configuration is incorrect.

## Installation

### 1. Deploy the Backup Script

The backup script is located at:
```
My-Scripts\src\powershell\backup\Backup-LiftSimulatorDatabase.ps1
```

### 2. Install the Scheduled Task

Run the installation script as **Administrator**:

```powershell
cd My-Scripts
.\scripts\Install-ScheduledTasks.ps1
```

This will automatically:
- Find the `PostgreSQL lift_simulator Backup.xml.template`
- Replace `{{SCRIPT_ROOT}}` with the actual script path
- Register the task in Windows Task Scheduler

**Manual Installation** (if needed):

```powershell
# Generate XML from template
$scriptRoot = "C:\path\to\My-Scripts"
$template = Get-Content "config\tasks\PostgreSQL lift_simulator Backup.xml.template" -Raw
$xml = $template -replace '\{\{SCRIPT_ROOT\}\}', $scriptRoot
$xml | Out-File "config\tasks\PostgreSQL lift_simulator Backup.xml" -Encoding UTF8

# Register task
Register-ScheduledTask -TaskName "MyScripts-PostgreSQL lift_simulator Backup" `
    -Xml (Get-Content "config\tasks\PostgreSQL lift_simulator Backup.xml" -Raw)
```

### 3. Verify Installation

Check the task is registered:

```powershell
Get-ScheduledTask -TaskName "*lift_simulator*"
```

### 4. Test the Backup

Run a manual backup test:

```powershell
# Option 1: Run via Task Scheduler
Start-ScheduledTask -TaskName "MyScripts-PostgreSQL lift_simulator Backup"

# Option 2: Run script directly
.\src\powershell\backup\Backup-LiftSimulatorDatabase.ps1
```

Check for:
- Backup file created: `D:\pgbackup\lift_simulator\lift_simulator_backup_YYYY-MM-DD_HH-mm-ss.backup`
- Log file created: `D:\pgbackup\lift_simulator\logs\lift_simulator_backup_YYYYMMDD-HHmmss.log`
- PowerShell log: `logs\Backup-LiftSimulatorDatabase.ps1_powershell_YYYY-MM-DD.log`

## Configuration

### Customizing Parameters

Edit the script parameters in `Backup-LiftSimulatorDatabase.ps1` if needed:

```powershell
param(
    [string]$Database = 'lift_simulator',           # Database name
    [string]$BackupRoot = 'D:\pgbackup\lift_simulator',  # Backup directory
    [string]$LogsRoot = 'D:\pgbackup\lift_simulator\logs', # Logs directory
    [string]$UserName = 'backup_user',              # PostgreSQL user
    [int]   $RetentionDays = 90,                    # Keep backups for 90 days
    [int]   $MinBackups = 3                         # Always keep at least 3 backups
)
```

### Changing the Schedule

Edit the scheduled task XML template at:
```
config\tasks\PostgreSQL lift_simulator Backup.xml.template
```

Modify the `<StartBoundary>` and `<ScheduleByDay>` elements, then re-run the installation script.

## Monitoring

### Check Backup Status

```powershell
# View recent backups
Get-ChildItem "D:\pgbackup\lift_simulator" -Filter "*.backup" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# View latest log
Get-ChildItem "D:\pgbackup\lift_simulator\logs" -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 20
```

### Check Task Scheduler History

```powershell
# Get last run result
Get-ScheduledTaskInfo -TaskName "MyScripts-PostgreSQL lift_simulator Backup" | Select-Object LastRunTime, LastTaskResult, NextRunTime

# View task history in Task Scheduler GUI
# Task Scheduler → Task Scheduler Library → My Scheduled Tasks → PostgreSQL lift_simulator Backup → History tab
```

### Log Locations

1. **Backup-specific logs**: `D:\pgbackup\lift_simulator\logs\lift_simulator_backup_*.log`
   - Contains pg_dump output and backup operation details

2. **PowerShell framework logs**: `My-Scripts\logs\Backup-LiftSimulatorDatabase.ps1_powershell_*.log`
   - Contains script execution logs with structured metadata

## Troubleshooting

### Common Issues

#### 1. "Missing .pgpass" Error
- Ensure `.pgpass` file exists at `%APPDATA%\postgresql\pgpass.conf`
- Verify entry format: `localhost:5432:lift_simulator:backup_user:password`
- Set `$env:PGPASSFILE` if using a custom location

#### 2. "Permission Denied" Error
- Verify `backup_user` has CONNECT and SELECT privileges (see "Grant Required Privileges")
- Check the user can connect: `psql -h localhost -U backup_user -d lift_simulator`

#### 3. "Service Failed to Start" Error
- Check PostgreSQL service status: `Get-Service postgresql-x64-17`
- Verify service name matches configuration
- Review Windows Event Viewer for PostgreSQL service errors

#### 4. Backup File is 0 Bytes
- Check database exists: `psql -U postgres -l | grep lift_simulator`
- Verify database is not empty
- Review backup log for pg_dump errors

#### 5. Task Fails to Run
- Ensure running as a user with access to backup directories
- Check Task Scheduler permissions and execution policy
- Verify PowerShell execution policy: `Get-ExecutionPolicy`

### Debug Mode

Run the backup script with verbose output:

```powershell
$VerbosePreference = 'Continue'
.\src\powershell\backup\Backup-LiftSimulatorDatabase.ps1 -Verbose
```

## Security Considerations

1. **Password Storage**: Never commit `.pgpass` or password files to version control
2. **File Permissions**: Restrict `.pgpass` to current user only (see "Authentication Setup")
3. **Backup Encryption**: Consider encrypting backup files at rest
4. **Least Privilege**: The `backup_user` should only have SELECT privileges (not UPDATE/DELETE)
5. **Audit Logs**: Regularly review backup logs for suspicious activity

## Backup Restoration

To restore from a backup:

```powershell
# Create a new database (if needed)
& "D:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -c "CREATE DATABASE lift_simulator_restore;"

# Restore from backup
& "D:\Program Files\PostgreSQL\17\bin\pg_restore.exe" `
    -U postgres `
    -d lift_simulator_restore `
    -v `
    "D:\pgbackup\lift_simulator\lift_simulator_backup_2026-01-12_07-30-45.backup"
```

**Note**: Custom format backups (`.backup` files) created with `pg_dump -Fc` must be restored with `pg_restore`, not `psql`.

## References

- [PostgresBackup Module Documentation](../modules/Database/PostgresBackup/README.md)
- [PowerShellLoggingFramework Documentation](../modules/Core/Logging/PowerShellLoggingFramework/README.md)
- [PostgreSQL pg_dump Documentation](https://www.postgresql.org/docs/current/app-pgdump.html)
- [PostgreSQL pg_restore Documentation](https://www.postgresql.org/docs/current/app-pgrestore.html)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs in `D:\pgbackup\lift_simulator\logs\`
3. Consult the lift-simulator project documentation
4. Contact the database administrator

---

**Last Updated**: 2026-01-12
**Version**: 1.0.0
**Author**: Manoj Bhaskaran
