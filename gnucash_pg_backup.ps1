# Define variables
$pg_dump_path = "D:\Program Files\PostgreSQL\17\bin\pg_dump.exe"  # Update path if different
$dbname = "gnucash_db"
$backup_folder = "D:\pgbackup\gnucash_db"
$log_folder = "D:\pgbackup\logs"
$date = Get-Date -Format "yyyy-MM-dd"
$time = Get-Date -Format "HH-mm-ss"
$backup_file = "$backup_folder\${dbname}_backup_${date}_${time}.backup"
$log_file = "$log_folder\backup_log.txt"
$retention_days = 90
$min_backups = 3
$user = "backup_user"
$password = "pgadminbackup"
$service_name = "postgresql-x64-17"
$service_start_wait = 5
$max_wait_time = 15  # Maximum wait time in seconds

# Ensure the backup folder exists
if (!(Test-Path -Path $backup_folder)) {
    New-Item -Path $backup_folder -ItemType Directory -Force
}

# Ensure the log folder exists
if (!(Test-Path -Path $log_folder)) {
    New-Item -Path $log_folder -ItemType Directory -Force
}

"$(Get-Date): ${dbname}: Backup Script started" | Out-File -FilePath $log_file -Append

# Function to wait for a service to reach a desired status with a maximum wait time
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
        "$(Get-Date): Service $ServiceName did not reach $DesiredStatus status within the maximum wait time of $MaxWaitTime seconds." | Out-File -FilePath $log_file -Append
        throw "Service $ServiceName did not reach $DesiredStatus status within the maximum wait time of $MaxWaitTime seconds."
    }
}

# Backup the database and log output
try {
    # Check the status of the PostgreSQL service
    $service = Get-Service -Name $service_name

    # Store the original status of the service
    $original_status = $service.Status

    # Start the service if it is not running
    if ($service.Status -ne 'Running') {
        "$(Get-Date): Postgres service ${service_name} not running. Starting service now..." | Out-File -FilePath $log_file -Append
        Start-Service -Name $service_name
        Wait-ServiceStatus -ServiceName $service_name -DesiredStatus 'Running' -MaxWaitTime $max_wait_time
    }

    & $pg_dump_path --dbname=postgresql://${user}:${password}@localhost/$dbname --file=$backup_file --format=custom *>&1 | Out-File -FilePath $log_file -Append
    # Check the exit code
    if ($LASTEXITCODE -eq 0) {
        "$(Get-Date): ${dbname}: Backup completed successfully: $backup_file" | Out-File -FilePath $log_file -Append
    } else {
        throw "$(Get-Date): ${dbname}: pg_dump failed with exit code $LASTEXITCODE."
    }

    # Stop the service if it was originally stopped
    if ($original_status -ne 'Running') {
        "$(Get-Date): Stopping Postgres service ${service_name}..." | Out-File -FilePath $log_file -Append
        Stop-Service -Name $service_name
        Wait-ServiceStatus -ServiceName $service_name -DesiredStatus 'Stopped' -MaxWaitTime $max_wait_time
    }

} catch {
    "$(Get-Date): ${dbname}: Backup failed: $_" | Out-File -FilePath $log_file -Append
    exit 1
}

# Function to delete old backups
Function Remove-OldBackups {
    $backup_files = Get-ChildItem -Path $backup_folder -Filter "${dbname}_backup_*.backup"
    $cutoff_date = (Get-Date).AddDays(-$retention_days)
    $files_deleted = $false

    # Count only the backups younger than the retention period
    $recent_backup_count = ($backup_files | Where-Object { $_.LastWriteTime -ge $cutoff_date }).Count

    # Delete backups older than the retention period if we have more than $min_backups recent backups
    if ($recent_backup_count -ge $min_backups) {
        $files_to_delete = $backup_files | Where-Object { $_.LastWriteTime -lt $cutoff_date }
        foreach ($file in $files_to_delete) {
            Remove-Item -Path $file.FullName -Force
            "$(Get-Date): ${dbname}: Deleted old backup: $($file.FullName)" | Out-File -FilePath $log_file -Append
            $files_deleted = $true
        }
    }

    return $files_deleted
}

# Function to clean up 0-byte backup files
Function Remove-ZeroByteBackups {
    $backup_files = Get-ChildItem -Path $backup_folder -Filter "${dbname}_backup_*.backup"
    $files_deleted = $false

    foreach ($file in $backup_files) {
        if ($file.Length -eq 0) {
            Remove-Item -Path $file.FullName -Force
            "$(Get-Date): ${dbname}: Deleted 0-byte backup: $($file.FullName)" | Out-File -FilePath $log_file -Append
            $files_deleted = $true
        }
    }

    return $files_deleted
}

# Call the cleanup functions and log output
try {
    $old_backups_deleted = Remove-OldBackups
    $zero_byte_backups_deleted = Remove-ZeroByteBackups

    if ($old_backups_deleted -or $zero_byte_backups_deleted) {
        "$(Get-Date): ${dbname}: Backup file cleanup completed successfully" | Out-File -FilePath $log_file -Append
    }
} catch {
    "$(Get-Date): ${dbname}: Backup file cleanup failed: $_" | Out-File -FilePath $log_file -Append
    exit 1
}

# End of your script
exit 0
