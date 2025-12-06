# PostgresBackup PowerShell Module

## Overview
Provides comprehensive PostgreSQL database backup functionality using `pg_dump` with automatic retention management, service control, and robust error handling.

## Version
Current version: **2.0.0**

## Installation

**Module import:**
```powershell
Import-Module PostgresBackup
```

**Manual import with path:**
```powershell
Import-Module .\src\powershell\modules\Database\PostgresBackup\PostgresBackup.psd1
```

**Using deployment script:**
```powershell
.\scripts\Deploy-Modules.ps1
```

## Prerequisites

- **PostgreSQL 17+** with `pg_dump` at `D:\Program Files\PostgreSQL\17\bin\pg_dump.exe`
- **PostgreSQL service:** `postgresql-x64-17`
- **Authentication:** `.pgpass` file at `%APPDATA%\postgresql\pgpass.conf` (recommended)
- **PowerShell 5.1+**

### .pgpass File Format

Create a `.pgpass` file for password-less authentication:

**Location:** `%APPDATA%\postgresql\pgpass.conf` (Windows) or `~/.pgpass` (Linux/macOS)

**Format:**
```
hostname:port:database:username:password
```

**Example:**
```
localhost:5432:job_scheduler:backup_user:SecurePassword123
localhost:5432:*:backup_user:SecurePassword123
```

**Permissions (Linux/macOS):**
```bash
chmod 600 ~/.pgpass
```

## Functions

### Backup-PostgresDatabase

Executes `pg_dump` to create a database backup with automatic retention management.

**Syntax:**
```powershell
Backup-PostgresDatabase [-dbname] <string> [-backup_folder] <string> [-log_file] <string>
    [-user] <string> [[-password] <SecureString>] [[-retention_days] <int>] [[-min_backups] <int>]
```

**Parameters:**

- **dbname** (string, mandatory)
  - PostgreSQL database name to backup
  - Example: `job_scheduler`, `timeline_data`

- **backup_folder** (string, mandatory)
  - Directory where backup files will be stored
  - Created automatically if it doesn't exist
  - Example: `D:\pgbackup\job_scheduler`

- **log_file** (string, mandatory)
  - Path to log file for backup operations
  - Includes timestamped entries in format: `[YYYYMMDD-HHMMSS] Message`
  - Example: `D:\pgbackup\job_scheduler\logs\backup_20250816.log`

- **user** (string, mandatory)
  - PostgreSQL user for authentication
  - Example: `backup_user`, `postgres`

- **password** (SecureString, optional)
  - Password for PostgreSQL authentication
  - If not provided or empty, uses `.pgpass` file
  - Convert plain text: `ConvertTo-SecureString "password" -AsPlainText -Force`

- **retention_days** (int, optional)
  - Number of days to retain backup files
  - Default: 90 days
  - Older backups are automatically deleted

- **min_backups** (int, optional)
  - Minimum number of recent backups to keep regardless of age
  - Default: 3
  - Ensures you always have at least N recent backups

**Returns:**
- Exit code 0 on success
- Exit code 1 on failure (Task Scheduler friendly)

**Examples:**

```powershell
# Basic backup using .pgpass for authentication
Backup-PostgresDatabase `
    -dbname 'job_scheduler' `
    -backup_folder 'D:\pgbackup\job_scheduler' `
    -log_file 'D:\pgbackup\job_scheduler\logs\backup.log' `
    -user 'backup_user'

# Backup with explicit password
$securePassword = ConvertTo-SecureString "MyPassword123" -AsPlainText -Force
Backup-PostgresDatabase `
    -dbname 'timeline_data' `
    -backup_folder 'D:\pgbackup\timeline' `
    -log_file 'D:\pgbackup\timeline\logs\backup.log' `
    -user 'postgres' `
    -password $securePassword

# Backup with custom retention policy
Backup-PostgresDatabase `
    -dbname 'gnucash' `
    -backup_folder 'D:\pgbackup\gnucash' `
    -log_file 'D:\pgbackup\gnucash\logs\backup.log' `
    -user 'backup_user' `
    -retention_days 180 `
    -min_backups 5

# Using .pgpass (recommended for scheduled tasks)
Backup-PostgresDatabase `
    -dbname 'job_scheduler' `
    -backup_folder 'D:\pgbackup\job_scheduler' `
    -log_file 'D:\pgbackup\job_scheduler\logs\backup_$(Get-Date -Format "yyyyMMdd").log' `
    -user 'backup_user' `
    -password (ConvertTo-SecureString "" -AsPlainText -Force)
```

## Features

### Automatic Service Management
- Checks PostgreSQL service status before backup
- Starts service if not running
- Waits up to 15 seconds for service to be ready
- Stops service after backup if it was initially stopped
- Configurable startup wait time (default: 5 seconds)

### Backup File Management
- Creates custom-format backups using `pg_dump -Fc`
- Backup filename format: `<dbname>_YYYYMMDD_HHMMSS.backup`
- Automatically removes zero-byte backup files
- Validates backup file creation

### Retention Management
- Automatic cleanup of old backup files
- Dual retention strategy:
  1. Age-based: Remove backups older than `retention_days`
  2. Count-based: Always keep at least `min_backups` recent backups
- Protects against accidental deletion of all backups

### Logging
- Standardized timestamp format: `[YYYYMMDD-HHMMSS]`
- Comprehensive operation logging
- Service status tracking
- Backup success/failure reporting
- Retention cleanup details

### Error Handling
- Exit code 1 on any failure (Task Scheduler compatible)
- Exit code 0 on success
- Detailed error messages in log file
- Service state restoration on failure

## Usage in Scripts

### Scheduled Backup Script

```powershell
# Backup-JobSchedulerDatabase.ps1
Import-Module "$PSScriptRoot\..\modules\Database\PostgresBackup\PostgresBackup.psm1" -Force

$backupDate = Get-Date -Format "yyyyMMdd"
$logFile = "D:\pgbackup\job_scheduler\logs\backup_$backupDate.log"

Backup-PostgresDatabase `
    -dbname 'job_scheduler' `
    -backup_folder 'D:\pgbackup\job_scheduler' `
    -log_file $logFile `
    -user 'backup_user' `
    -password (ConvertTo-SecureString "" -AsPlainText -Force) `
    -retention_days 90 `
    -min_backups 3

# Exit code is propagated for Task Scheduler
exit $LASTEXITCODE
```

### Windows Task Scheduler Integration

**Task Configuration:**
- **Action:** Start a program
- **Program:** `powershell.exe`
- **Arguments:** `-ExecutionPolicy Bypass -File "C:\Scripts\Backup-JobSchedulerDatabase.ps1"`
- **Run with highest privileges:** Yes (required for service management)

## Backup File Format

Backups are created in PostgreSQL custom format (`pg_dump -Fc`), which:
- Provides best compression
- Allows selective restoration
- Includes all database objects
- Can be restored with `pg_restore`

**Restore Example:**
```bash
pg_restore -U backup_user -d job_scheduler -c D:\pgbackup\job_scheduler\job_scheduler_20250816_143022.backup
```

## Configuration

The module uses these hardcoded paths (configurable by editing the module):

```powershell
$pg_dump_path = "D:\Program Files\PostgreSQL\17\bin\pg_dump.exe"
$service_name = "postgresql-x64-17"
$service_start_wait = 5   # seconds to wait after service start
$max_wait_time = 15       # maximum wait for service readiness
```

## Dependencies

- PowerShell 5.1 or later
- PostgreSQL 17+ client tools
- Windows Service Control Manager access (for service management)

## Technical Details

**Module GUID:** `4f7b8a9c-2e6d-4b3a-9f8e-1c5a7d9b2e4f`

**Tags:** postgresql, backup, database, retention, pg_dump

**Author:** Manoj Bhaskaran

## Used By

- `src/powershell/backup/Backup-JobSchedulerDatabase.ps1` - Job scheduler database backups
- `src/powershell/backup/Backup-PostgreSqlCommon.ps1` - Common PostgreSQL backup wrapper
- Task Scheduler jobs for automated database backups

## Troubleshooting

### "pg_dump not found"
- Verify PostgreSQL is installed at `D:\Program Files\PostgreSQL\17\`
- Update `$pg_dump_path` in the module if using a different version or location

### "Password authentication failed"
- Check `.pgpass` file exists and has correct format
- Verify file permissions (should not be world-readable on Linux/macOS)
- Ensure the user has backup privileges: `GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;`

### "Service start timeout"
- Increase `$max_wait_time` in the module
- Check PostgreSQL service logs for startup issues
- Verify Windows Service is configured correctly

### "Access Denied" when managing service
- Run PowerShell as Administrator
- Verify user has Service Control Manager permissions

### Zero-byte backup files
- These are automatically cleaned up by the module
- Usually indicates pg_dump failed (check log file)
- Verify database exists and user has permissions

## Testing

The PostgresBackup module has comprehensive test coverage to ensure reliability and prevent data loss.

### Test Suite

**Unit Tests:** `tests/powershell/unit/PostgresBackup.Tests.ps1`
- **Total Test Cases:** 40
- **Test Code Lines:** 1,320
- **Coverage:** All public functions and edge cases

**Test Categories:**
- ✅ **Backup Creation** (5 tests) - File creation, naming conventions, logging
- ✅ **Service Management** (3 tests) - Start/stop behavior, state preservation
- ✅ **Retention Policy** (8 tests) - Age-based cleanup, min_backups threshold, edge cases
- ✅ **Error Handling** (11 tests) - Database errors, disk space, permissions, service failures
- ✅ **Password Handling** (6 tests) - .pgpass, SecureString, URL encoding, special characters
- ✅ **Custom Format** (2 tests) - pg_dump format validation
- ✅ **Invalid Database Scenarios** (4 tests) - Non-existent DB, timeouts, auth failures
- ✅ **Special Characters** (4 tests) - URL encoding, special chars in passwords/usernames

**Integration Tests:** `tests/integration/Test-BackupRestore.Tests.ps1`
- Real PostgreSQL instance with actual backup/restore
- Data integrity validation
- Retention policy enforcement

### Running Tests

```powershell
# Run all PostgreSQL backup tests
.\tests\powershell\Invoke-Tests.ps1

# Run with code coverage
.\tests\powershell\Invoke-Tests.ps1 -CodeCoverageEnabled $true -MinimumCoverage 30

# Run specific test file
Invoke-Pester -Path .\tests\powershell\unit\PostgresBackup.Tests.ps1
```

**Test Requirements:**
- Pester 5.0.0+
- Windows platform (tests skip on Linux/macOS)
- No actual PostgreSQL installation required for unit tests (uses mocks)

### Test Coverage

The test suite achieves **8.1:1 test-to-code ratio** (1,320 test lines / 162 implementation lines), covering:
- ✅ All success paths
- ✅ All error conditions
- ✅ Edge cases and boundary conditions
- ✅ Special character handling
- ✅ Service management scenarios
- ✅ Retention policy variations

## License

MIT License

---

For module history, see [CHANGELOG.md](./CHANGELOG.md).
