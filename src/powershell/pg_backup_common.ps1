<#
.SYNOPSIS
    Wrapper script to import the PostgresBackup module for backwards compatibility.
.DESCRIPTION
    This script imports the PostgresBackup PowerShell module to provide the Backup-PostgresDatabase function, ensuring compatibility with existing scripts that dot source pg_backup_common.ps1. It is used in environments where scripts rely on the original pg_backup_common.ps1 file for PostgreSQL database backups.
.NOTES
    Version: 1.0.0
    Date: 2025-07-03
    License: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
    Requires:
        - PostgresBackup module installed at C:\Program Files\WindowsPowerShell\Modules\PostgresBackup\PostgresBackup.psm1.
#>

# Import the PostgresBackup module to provide Backup-PostgresDatabase function
try {
    Import-Module PostgresBackup -ErrorAction Stop
    Write-Verbose "Successfully imported PostgresBackup module"
} catch {
    Write-Error "Failed to import PostgresBackup module: $_"
    exit 1
}