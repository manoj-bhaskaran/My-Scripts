<#
.SYNOPSIS
    PowerShell module for backing up PostgreSQL databases.
.DESCRIPTION
    The PostgresBackup module provides functionality to back up PostgreSQL databases using pg_dump. It manages the PostgreSQL service, creates custom-format backups, and handles retention policies to remove old or zero-byte backups. The module is designed for use in scripts executed via Windows Task Scheduler, with support for secure password management via .pgpass files. All log entries use the [YYYYMMDD-HHMMSS] timestamp format for consistency.
.NOTES
    Version: 1.0.2
    Date: 2025-08-16
    License: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
    Requires: 
        - PostgreSQL 17 or compatible, with pg_dump installed at D:\Program Files\PostgreSQL\17\bin\pg_dump.exe.
        - A .pgpass file at %APPDATA%\postgresql\pgpass.conf (e.g., C:\Users\<User>\AppData\Roaming\postgresql\pgpass.conf) with format: localhost:5432:<database>:<user>:<password>.
        - Write access to the backup and log folders for the executing user.
#>

# Environment-specific configuration
$pg_dump_path = "D:\Program Files\PostgreSQL\17\bin\pg_dump.exe" # Path to pg_dump executable
$service_name = "postgresql-x64-17"                              # PostgreSQL service name
$service_start_wait = 5                                          # Seconds to wait between service status checks
$max_wait_time = 15                                              # Maximum seconds to wait for service status change

<#
.SYNOPSIS
    Backs up a PostgreSQL database using pg_dump and manages backup retention.
.DESCRIPTION
    This function performs a backup of a specified PostgreSQL database using the pg_dump utility in custom format. It ensures the PostgreSQL service is running, creates a backup file, and applies retention policies to delete old or zero-byte backups. Logs are written to the specified log file with timestamps in [YYYYMMDD-HHMMSS] format.
.PARAMETER dbname
    The name of the PostgreSQL database to back up (e.g., job_scheduler).
.PARAMETER backup_folder
    The directory where backup files are stored (e.g., D:\pgbackup\job_scheduler).
.PARAMETER log_file
    The file where log entries are written (e.g., D:\pgbackup\job_scheduler\job_scheduler_backup_YYYYMMDD-HHMMSS.log).
.PARAMETER user
    The PostgreSQL user for authentication (e.g., backup_user).
.PARAMETER password
    A SecureString password for authentication. If empty, authentication relies on a .pgpass file.
.PARAMETER retention_days
    The number of days to retain backups (default: 90). Older backups are deleted if min_backups is satisfied.
.PARAMETER min_backups
    The minimum number of recent backups to retain (default: 3), preventing deletion of recent backups.
.EXAMPLE
    Backup-PostgresDatabase -dbname "job_scheduler" -backup_folder "D:\pgbackup\job_scheduler" -log_file "D:\pgbackup\job_scheduler\job_scheduler_backup_20250816-144334.log" -user "backup_user" -password (ConvertTo-SecureString "" -AsPlainText -Force) -retention_days 90 -min_backups 3
    Backs up the job_scheduler database, storing the backup and logging to the specified file, using .pgpass for authentication.
.NOTES
    - Ensure pg_dump is accessible at the specified $pg_dump_path.
    - The function exits with code 1 on failure, 0 on success.
    - Logs are appended to the specified log_file with timestamps in [YYYYMMDD-HHMMSS] format.
#>
function Backup-PostgresDatabase {
    param (
        [Parameter(Mandatory=$true)]
        [string]$dbname,
        [Parameter(Mandatory=$true)]
        [string]$backup_folder,
        [Parameter(Mandatory=$true)]
        [string]$log_file,
        [Parameter(Mandatory=$true)]
        [string]$user,
        [Parameter(Mandatory=$false)]
        [SecureString]$password,
        [Parameter(Mandatory=$false)]
        [int]$retention_days = 90,
        [Parameter(Mandatory=$false)]
        [int]$min_backups = 3
    )

    # Generate timestamped backup file name
    $date = Get-Date -Format "yyyy-MM-dd"
    $time = Get-Date -Format "HH-mm-ss"
    $backup_file = "$backup_folder\${dbname}_backup_${date}_${time}.backup"

    # Ensure backup directory exists
    if (!(Test-Path -Path $backup_folder)) {
        New-Item -Path $backup_folder -ItemType Directory -Force | Out-Null
    }

    # Ensure log file directory exists
    $log_folder = Split-Path -Parent $log_file
    if (!(Test-Path -Path $log_folder)) {
        New-Item -Path $log_folder -ItemType Directory -Force | Out-Null
    }

    # Log start of backup process with standardized timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    "[$timestamp] ${dbname}: Backup Script started" | Out-File -FilePath $log_file -Append

    # Internal function to wait for a service to reach a desired status
    function Wait-ServiceStatus {
        param (
            [string]$ServiceName,
            [string]$DesiredStatus,
            [int]$MaxWaitTime
        )
        $elapsedTime = 0
        while ((Get-Service -Name $ServiceName).Status -ne $DesiredStatus -and $elapsedTime -lt $MaxWaitTime) {
            Start-Sleep -Seconds $service_start_wait
            $elapsedTime += $service_start_wait
        }
        if ((Get-Service -Name $ServiceName).Status -ne $DesiredStatus) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            "[$timestamp] Service $ServiceName did not reach $DesiredStatus status within the maximum wait time of $MaxWaitTime seconds." | Out-File -FilePath $log_file -Append
            throw "Service $ServiceName did not reach $DesiredStatus status within the maximum wait time of $MaxWaitTime seconds."
        }
    }

    try {
        # Check and start PostgreSQL service if not running
        $service = Get-Service -Name $service_name
        $original_status = $service.Status
        if ($service.Status -ne 'Running') {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            "[$timestamp] Postgres service ${service_name} not running. Starting service now..." | Out-File -FilePath $log_file -Append
            Start-Service -Name $service_name
            Wait-ServiceStatus -ServiceName $service_name -DesiredStatus 'Running' -MaxWaitTime $max_wait_time
        }

        # Handle password, defaulting to empty string for .pgpass authentication
        $PlainPassword = if ($password) { (New-Object System.Management.Automation.PSCredential($user, $password)).GetNetworkCredential().Password } else { "" }
        $EscapedPassword = [System.Net.WebUtility]::UrlEncode($PlainPassword)

        # Execute pg_dump to create a custom-format backup
        & $pg_dump_path --dbname="postgresql://${user}:${EscapedPassword}@localhost/${dbname}" --file=$backup_file --format=custom *>&1 | Out-File -FilePath $log_file -Append
        if ($LASTEXITCODE -eq 0) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            "[$timestamp] ${dbname}: Backup completed successfully: $backup_file" | Out-File -FilePath $log_file -Append
        } else {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            throw "[$timestamp] ${dbname}: pg_dump failed with exit code $LASTEXITCODE."
        }

        # Stop PostgreSQL service if it was not running initially
        if ($original_status -ne 'Running') {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            "[$timestamp] Stopping Postgres service ${service_name}..." | Out-File -FilePath $log_file -Append
            Stop-Service -Name $service_name
            Wait-ServiceStatus -ServiceName $service_name -DesiredStatus 'Stopped' -MaxWaitTime $max_wait_time
        }
    } catch {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        "[$timestamp] ${dbname}: Backup failed: $_" | Out-File -FilePath $log_file -Append
        exit 1
    }

    # Internal function to remove backups older than retention_days
    function Remove-OldBackups {
        $backup_files = Get-ChildItem -Path $backup_folder -Filter "${dbname}_backup_*.backup"
        $cutoff_date = (Get-Date).AddDays(-$retention_days)
        $files_deleted = $false
        $recent_backup_count = ($backup_files | Where-Object { $_.LastWriteTime -ge $cutoff_date }).Count
        if ($recent_backup_count -ge $min_backups) {
            $files_to_delete = $backup_files | Where-Object { $_.LastWriteTime -lt $cutoff_date }
            foreach ($file in $files_to_delete) {
                Remove-Item -Path $file.FullName -Force
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                "[$timestamp] ${dbname}: Deleted old backup: $($file.FullName)" | Out-File -FilePath $log_file -Append
                $files_deleted = $true
            }
        }
        return $files_deleted
    }

    # Internal function to remove zero-byte backup files
    function Remove-ZeroByteBackups {
        $backup_files = Get-ChildItem -Path $backup_folder -Filter "${dbname}_backup_*.backup"
        $files_deleted = $false
        foreach ($file in $backup_files) {
            if ($file.Length -eq 0) {
                Remove-Item -Path $file.FullName -Force
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                "[$timestamp] ${dbname}: Deleted 0-byte backup: $($file.FullName)" | Out-File -FilePath $log_file -Append
                $files_deleted = $true
            }
        }
        return $files_deleted
    }

    try {
        # Apply retention policies
        $old_backups_deleted = Remove-OldBackups
        $zero_byte_backups_deleted = Remove-ZeroByteBackups
        if ($old_backups_deleted -or $zero_byte_backups_deleted) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            "[$timestamp] ${dbname}: Backup file cleanup completed successfully" | Out-File -FilePath $log_file -Append
        }
    } catch {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        "[$timestamp] ${dbname}: Backup file cleanup failed: $_" | Out-File -FilePath $log_file -Append
        exit 1
    }
}

# Export the Backup-PostgresDatabase function to make it available when the module is imported
Export-ModuleMember -Function Backup-PostgresDatabase