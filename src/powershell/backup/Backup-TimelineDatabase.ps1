<#
.SYNOPSIS
    Backup script for Timeline database with secure password handling.

.DESCRIPTION
    Backs up the timeline_data database using PostgreSQL pg_dump with secure password management.
    Supports environment variables and relative paths for portability.

.PARAMETER PasswordFile
    Path to the encrypted password file. If not specified, uses environment variable
    PGBACKUP_PASSWORD_FILE or defaults to config/secrets/pgbackup_user_pwd.txt

.NOTES
    VERSION: 2.1.0
    CHANGELOG:
        2.0.0 - Removed hardcoded paths, added portable path resolution (Issue #513)
        1.0.0 - Initial release
#>

[CmdletBinding()]
param(
    [string]$PasswordFile
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# Parameters for timeline_data backup
$dbname = "timeline_data"
$backup_folder = "D:\pgbackup\timeline_data"
$log_folder = "D:\pgbackup\logs"
$user = "backup_user"
$retention_days = 90
$min_backups = 3

# Determine password file location
if (-not $PasswordFile) {
    # Try environment variable first
    if ($env:PGBACKUP_PASSWORD_FILE) {
        $PasswordFile = $env:PGBACKUP_PASSWORD_FILE
        Write-LogInfo "Using password file from environment variable" -Metadata @{ PasswordFile = $PasswordFile }
    }
    # Fall back to config directory (relative to repository root)
    else {
        # Navigate from script location to repository root
        $scriptRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $PasswordFile = Join-Path $scriptRoot "config" "secrets" "pgbackup_user_pwd.txt"
        Write-LogInfo "Using default password file location" -Metadata @{ PasswordFile = $PasswordFile }
    }
}

# Validate password file exists
if (-not (Test-Path $PasswordFile)) {
    $errorMsg = @"
Password file not found: $PasswordFile

To fix this issue:
1. Create the password file using:
   Read-Host "Enter pgbackup user password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "$PasswordFile"

2. Or set the PGBACKUP_PASSWORD_FILE environment variable:
   [Environment]::SetEnvironmentVariable("PGBACKUP_PASSWORD_FILE", "C:\path\to\password.txt", "User")

3. Ensure the password file is in the secure config directory and NOT committed to version control.
"@
    Write-LogError $errorMsg
    throw "Password file not found: $PasswordFile"
}

Write-LogInfo "Validated password file location" -Metadata @{ PasswordFile = $PasswordFile }

# Read password securely
try {
    $password = Get-Content $PasswordFile -ErrorAction Stop | ConvertTo-SecureString -ErrorAction Stop
    Write-LogInfo "Password loaded successfully"
}
catch {
    Write-LogError "Failed to read or decrypt password file" -Metadata @{ Error = $_ }
    Write-LogError "The password file may be corrupted or not properly encrypted."
    Write-LogError "Recreate it using: Read-Host 'Enter password' -AsSecureString | ConvertFrom-SecureString | Out-File '$PasswordFile'"
    throw "Failed to read password: $_"
}

# Call the common backup script
try {
    $invokeResult = & "$PSScriptRoot\pg_backup_common.ps1" `
        -dbname $dbname `
        -backup_folder $backup_folder `
        -log_folder $log_folder `
        -user $user `
        -password $password `
        -retention_days $retention_days `
        -min_backups $min_backups

    Write-LogInfo "Backup invocation completed" -Metadata @{ Database = $dbname; BackupFolder = $backup_folder }

    Write-Output ([PSCustomObject]@{
            Database      = $dbname
            BackupFolder  = $backup_folder
            LogFolder     = $log_folder
            User          = $user
            RetentionDays = $retention_days
            MinBackups    = $min_backups
            PasswordFile  = $PasswordFile
            Result        = $invokeResult
            Status        = "Success"
        })
}
catch {
    Write-LogError "Backup invocation failed" -Metadata @{ Database = $dbname; Error = $_ }
    throw
}
