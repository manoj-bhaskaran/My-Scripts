<#
.SYNOPSIS
    Backs up the job_scheduler PostgreSQL database using the PostgresBackup module.
.DESCRIPTION
    This script performs a backup of the job_scheduler PostgreSQL database, designed for execution via Windows Task Scheduler. 
    It uses the backup_user account with a .pgpass file for secure password management and logs all operations to a timestamped 
    log file. The script uses the PostgresBackup PowerShell module, which writes additional logs to backup_log.txt in the 
    backup folder. The script ensures the backup directory exists and sets appropriate exit codes for Task Scheduler (0 for success, 1 for failure).
.PREREQUISITES
    - PostgreSQL and pg_dump (version 17 or compatible) installed at D:\Program Files\PostgreSQL\17\bin\pg_dump.exe.
    - PostgresBackup module installed at C:\Program Files\WindowsPowerShell\Modules\PostgresBackup\PostgresBackup.psm1.
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
    - The script relies on .pgpass for authentication, as the PostgresBackup module supports empty passwords.
    - Exit codes: 0 (success), 1 (failure).
    - The PostgresBackup module replaces the previous pg_backup_common.ps1 dependency to eliminate path issues.
#>

# Licensed under the Apache License, Version 2.0
# See http://www.apache.org/licenses/LICENSE-2.0 for details

# Backup script for the job_scheduler PostgreSQL database
# Uses PostgresBackup module for backup functionality
# Designed for Windows Task Scheduler, logs all output to a file
# Uses .pgpass for secure password management with backup_user

# Get the script's directory for relative path calculations
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Configuration
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$DatabaseName = "job_scheduler"
$OutputFolder = Join-Path $ScriptDir "..\..\backups\job_scheduler"
$LogFile = Join-Path $OutputFolder "job_scheduler_backup_$Timestamp.log"
$LogFolder = $OutputFolder  # Match log_folder to backup_folder for PostgresBackup module
$User = "backup_user"

# Ensure backup directory exists
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

# Log script start
Add-Content -Path $LogFile -Value "[$Timestamp] Starting job_scheduler backup"

# Import PostgresBackup module
try {
    Import-Module PostgresBackup -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$Timestamp] PostgresBackup module imported successfully"
} catch {
    Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Failed to import PostgresBackup module: $_"
    exit 1
}

# Verify Backup-PostgresDatabase function is available
if (-not (Get-Command -Name Backup-PostgresDatabase -ErrorAction SilentlyContinue)) {
    Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Backup-PostgresDatabase function not found in PostgresBackup module"
    exit 1
}

# Run the backup
try {
    Backup-PostgresDatabase -dbname $DatabaseName -backup_folder $OutputFolder -log_folder $LogFolder -user $User -retention_days 90 -min_backups 3
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