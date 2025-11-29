<#
.SYNOPSIS
    Backup script for GnuCash database with secure password handling.

.DESCRIPTION
    Backs up the gnucash_db database using PostgreSQL pg_dump with secure password management.
    Supports environment variables and relative paths for portability.

.PARAMETER PasswordFile
    Path to the encrypted password file. If not specified, uses environment variable
    PGBACKUP_PASSWORD_FILE or defaults to config/secrets/pgbackup_user_pwd.txt

.NOTES
    VERSION: 2.0.0
    CHANGELOG:
        2.0.0 - Removed hardcoded paths, added portable path resolution (Issue #513)
        1.0.0 - Initial release
#>

[CmdletBinding()]
param(
    [string]$PasswordFile
)

# Parameters for gnucash_db backup
$dbname = "gnucash_db"
$backup_folder = "D:\pgbackup\gnucash_db"
$log_folder = "D:\pgbackup\logs"
$user = "backup_user"
$retention_days = 90
$min_backups = 3

# Determine password file location
if (-not $PasswordFile) {
    # Try environment variable first
    if ($env:PGBACKUP_PASSWORD_FILE) {
        $PasswordFile = $env:PGBACKUP_PASSWORD_FILE
        Write-Verbose "Using password file from environment variable: $PasswordFile"
    }
    # Fall back to config directory (relative to repository root)
    else {
        # Navigate from script location to repository root
        $scriptRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $PasswordFile = Join-Path $scriptRoot "config" "secrets" "pgbackup_user_pwd.txt"
        Write-Verbose "Using default password file location: $PasswordFile"
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
    Write-Error $errorMsg
    throw "Password file not found: $PasswordFile"
}

Write-Verbose "Using password file: $PasswordFile"

# Read password securely
try {
    $password = Get-Content $PasswordFile -ErrorAction Stop | ConvertTo-SecureString -ErrorAction Stop
    Write-Verbose "Password loaded successfully"
}
catch {
    Write-Error "Failed to read or decrypt password file: $_"
    Write-Error "The password file may be corrupted or not properly encrypted."
    Write-Error "Recreate it using: Read-Host 'Enter password' -AsSecureString | ConvertFrom-SecureString | Out-File '$PasswordFile'"
    throw "Failed to read password: $_"
}

# Call the common backup script
& "$PSScriptRoot\pg_backup_common.ps1" `
    -dbname $dbname `
    -backup_folder $backup_folder `
    -log_folder $log_folder `
    -user $user `
    -password $password `
    -retention_days $retention_days `
    -min_backups $min_backups
