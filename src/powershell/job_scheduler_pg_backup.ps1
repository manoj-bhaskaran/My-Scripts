<#
.SYNOPSIS
    Backs up the job_scheduler PostgreSQL database using pg_backup_common.ps1.
.DESCRIPTION
    This script performs a backup of the job_scheduler PostgreSQL database, designed for execution via Windows Task Scheduler. 
    It uses the backup_user account with a .pgpass file for secure password management and logs all operations to a timestamped 
    log file. The script calls the unmodifiable pg_backup_common.ps1, which writes additional logs to backup_log.txt in the 
    backup folder. The script ensures the backup directory exists, validates the presence of pg_backup_common.ps1, and sets 
    appropriate exit codes for Task Scheduler (0 for success, 1 for failure).
.PREREQUISITES
    - PostgreSQL and pg_dump (version 17 or compatible) installed.
    - pg_backup_common.ps1 located at ..\..\My-Scripts\src\powershell\pg_backup_common.ps1 relative to this script.
    - A .pgpass file configured for backup_user at %APPDATA%\postgresql\pgpass.conf (e.g., 
      C:\Users\<ServiceAccount>\AppData\Roaming\postgresql\pgpass.conf) with the entry:
      localhost:5432:job_scheduler:backup_user:<password>
    - The .pgpass file must have restricted permissions (accessible only to the Task Scheduler service account).
    - The Task Scheduler service account must have write access to the backup folder.
.EXAMPLE
    powershell.exe -File .\job_scheduler_pg_backup.ps1
    Runs the script to back up the job_scheduler database, creating a backup in ..\..\backups\job_scheduler and logging to 
    a timestamped log file in the same folder.
.NOTES
    - Logs are written to a timestamped file (job_scheduler_backup_YYYYMMDD-HHMMSS.log) and to backup_log.txt in the backup folder.
    - The script uses a dummy empty password to ensure pg_dump authenticates via .pgpass, as pg_backup_common.ps1 requires a 
      password parameter.
    - Exit codes: 0 (success), 1 (failure).
#>

# Licensed under the Apache License, Version 2.0
# See http://www.apache.org/licenses/LICENSE-2.0 for details

# Backup script for the job_scheduler PostgreSQL database
# Requires pg_backup_common.ps1 from My-Scripts repository
# Designed for Windows Task Scheduler, logs all output to a file
# Uses .pgpass for secure password management with backup_user

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CommonScript = Join-Path $ScriptDir "..\..\My-Scripts\src\powershell\pg_backup_common.ps1"

# Configuration
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$DatabaseName = "job_scheduler"
$OutputFolder = Join-Path $ScriptDir "..\..\backups\job_scheduler"
$LogFile = Join-Path $OutputFolder "job_scheduler_backup_$Timestamp.log"
$LogFolder = $OutputFolder  # Match log_folder to backup_folder for pg_backup_common.ps1
$User = "backup_user"
$DummyPassword = ConvertTo-SecureString "" -AsPlainText -Force

# Ensure backup directory exists
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

# Log script start
Add-Content -Path $LogFile -Value "[$Timestamp] Starting job_scheduler backup"

# Check for pg_backup_common.ps1
if (-not (Test-Path $CommonScript)) {
    Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Common script $CommonScript not found"
    exit 1
}

# Source common script
. $CommonScript

# Run the backup
try {
    Backup-PostgresDatabase -dbname $DatabaseName -backup_folder $OutputFolder -log_folder $LogFolder -user $User -password $DummyPassword -retention_days 90 -min_backups 3
    if ($LASTEXITCODE -eq 0) {
        Add-Content -Path $LogFile -Value "[$Timestamp] Backup completed successfully. Check $LogFolder\backup_log.txt for details"
        exit 0
    } else {
        Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Backup failed with exit code $LASTEXITCODE. Check $LogFolder\backup_log.txt for details"
        exit 1
    }
} catch {
    Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Backup failed: $_"
    exit 1
}