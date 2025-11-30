function Backup-PostgresDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$dbname,
        [Parameter(Mandatory = $true)]
        [string]$backup_folder,
        [Parameter(Mandatory = $true)]
        [string]$log_file,
        [Parameter(Mandatory = $true)]
        [string]$user,
        [Parameter(Mandatory = $false)]
        [SecureString]$password,
        [Parameter(Mandatory = $false)]
        [int]$retention_days = 90,
        [Parameter(Mandatory = $false)]
        [int]$min_backups = 3
    )

    # Generate timestamped backup file name
    $date = Get-Date -Format "yyyy-MM-dd"
    $time = Get-Date -Format "HH-mm-ss"
    $backup_file = "$backup_folder\\${dbname}_backup_${date}_${time}.backup"

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
    Add-Content -Path $log_file -Value "[$timestamp] ${dbname}: Backup Script started" -Encoding utf8

    try {
        # Check and start PostgreSQL service if not running
        $service = Get-Service -Name $service_name
        $original_status = $service.Status
        if ($service.Status -ne 'Running') {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            Add-Content -Path $log_file -Value "[$timestamp] Postgres service ${service_name} not running. Starting service now..." -Encoding utf8
            Start-Service -Name $service_name
            Wait-ServiceStatus -ServiceName $service_name -DesiredStatus 'Running' -MaxWaitTime $max_wait_time -PollSeconds $service_start_wait -LogFilePath $log_file
        }

        # Handle password, defaulting to empty string for .pgpass authentication
        $PlainPassword = if ($password) { (New-Object System.Management.Automation.PSCredential($user, $password)).GetNetworkCredential().Password } else { "" }
        $EscapedPassword = [System.Net.WebUtility]::UrlEncode($PlainPassword)

        # Execute pg_dump to create a custom-format backup
        & $pg_dump_path --dbname="postgresql://${user}:${EscapedPassword}@localhost/${dbname}" --file=$backup_file --format=custom *>&1 | Add-Content -Path $log_file -Encoding utf8
        if ($LASTEXITCODE -eq 0) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            Add-Content -Path $log_file -Value "[$timestamp] ${dbname}: Backup completed successfully: $backup_file" -Encoding utf8
        }
        else {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            throw "[$timestamp] ${dbname}: pg_dump failed with exit code $LASTEXITCODE."
        }

        # Stop PostgreSQL service if it was not running initially
        if ($original_status -ne 'Running') {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            Add-Content -Path $log_file -Value "[$timestamp] Stopping Postgres service ${service_name}..." -Encoding utf8
            Stop-Service -Name $service_name
            Wait-ServiceStatus -ServiceName $service_name -DesiredStatus 'Stopped' -MaxWaitTime $max_wait_time -PollSeconds $service_start_wait -LogFilePath $log_file
        }
    }
    catch {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Add-Content -Path $log_file -Value "[$timestamp] ${dbname}: Backup failed: $_" -Encoding utf8
        exit 1
    }

    try {
        # Apply retention policies
        $old_backups_deleted = Remove-OldBackups -BackupFolder $backup_folder -DatabaseName $dbname -LogFile $log_file -RetentionDays $retention_days -MinBackups $min_backups
        $zero_byte_backups_deleted = Remove-ZeroByteBackups -BackupFolder $backup_folder -DatabaseName $dbname -LogFile $log_file
        if ($old_backups_deleted -or $zero_byte_backups_deleted) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            Add-Content -Path $log_file -Value "[$timestamp] ${dbname}: Backup file cleanup completed successfully" -Encoding utf8
        }
    }
    catch {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Add-Content -Path $log_file -Value "[$timestamp] ${dbname}: Backup file cleanup failed: $_" -Encoding utf8
        exit 1
    }
}
