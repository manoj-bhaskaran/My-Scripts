<#
 .VERSION
     3.0.0
.SYNOPSIS
    Runs a PostgreSQL backup for the timeline_data database via the PostgresBackup module.

.DESCRIPTION
    - Ensures backup and log folders exist under:
        D:\pgbackup\timeline_data\
        D:\pgbackup\timeline_data\logs
    - Builds a timestamped log file in the logs folder and passes it to the module.
    - Imports the PostgresBackup module (highest available version on PSModulePath).
    - Invokes Backup-PostgresDatabase with retention defaults.
    - Returns exit code 0 on success, 1 on failure (Task Scheduler friendly).

.NOTES
    CHANGELOG
    ## 3.0.0 - 2026-01-12
    ### Changed
    - Migrated from encrypted password file to .pgpass authentication
    - Replaced pg_backup_common.ps1 call with PostgresBackup module
    - Aligned with lift_simulator backup architecture
    - Uses PowerShellLoggingFramework for standardized logging
    - Implements .pgpass authentication validation with ACL checks

    ## 2.1.0 - Previous
    - Removed hardcoded paths, added portable path resolution (Issue #513)

    ## 1.0.0 - Initial
    - Initial release with encrypted password file

    Authentication uses .pgpass for backup_user.
    Requires:
      - PostgresBackup module deployed/available on PSModulePath
      - .pgpass (or equivalent) with entry for timeline_data database
      - backup_user with sufficient privileges on timeline_data database
    Author: Manoj Bhaskaran
    Last Updated: 2026-01-12
#>

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# === Preflight & Hardening ===
$ErrorActionPreference = 'Stop'

# Resolve .pgpass and enforce explicit use via PGPASSFILE
$PgPass = if ($env:PGPASSFILE) { $env:PGPASSFILE } else { Join-Path $env:APPDATA 'postgresql\pgpass.conf' }

if (-not (Test-Path -LiteralPath $PgPass)) {
    throw "Missing .pgpass at '$PgPass'. Create it or set PGPASSFILE to a valid path."
}

# Set PGPASSFILE explicitly so libpq uses the intended file
$env:PGPASSFILE = $PgPass

# ACL sanity warning (Windows): discourage wide-readable ACLs
try {
    $acl = Get-Acl -LiteralPath $PgPass
    $bad = $acl.Access | Where-Object {
        $_.IdentityReference -match 'Everyone|Users|Authenticated Users'
    }
    if ($bad) {
        Write-Warning ("Suspicious ACLs on .pgpass: " + (($bad | Select-Object -ExpandProperty IdentityReference | Select-Object -Unique) -join ', ') + ". Restrict access to the current user for better security.")
    }
}
catch {
    Write-Warning "Could not inspect ACLs for .pgpass at '$PgPass': $($_.Exception.Message)"
}
# === End Preflight ===

function Invoke-BackupMain {

    [CmdletBinding()]
    param(
        # Override defaults if needed when calling from Task Scheduler
        [string]$Database = 'timeline_data',
        [string]$BackupRoot = 'D:\pgbackup\timeline_data',          # where .backup files go
        [string]$LogsRoot = 'D:\pgbackup\timeline_data\logs',      # where .log files go
        [string]$UserName = 'backup_user',                         # PG user
        [int]   $RetentionDays = 90,
        [int]   $MinBackups = 3,

        # If you want to force a specific PostgresBackup version, set this (e.g., '1.0.4')
        [string]$ModuleVersion
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # ----- Helpers -----
    function New-DirectoryIfMissing {
        param([Parameter(Mandatory = $true)][string]$Path)
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    }

    # ----- Ensure folders -----
    try {
        New-DirectoryIfMissing -Path $BackupRoot
        New-DirectoryIfMissing -Path $LogsRoot
    }
    catch {
        Write-LogError "ERROR: Failed to ensure backup/log directories: $_"
        exit 1
    }

    # ----- Build timestamped log path (module will append UTF-8) -----
    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $LogFile = Join-Path $LogsRoot ("{0}_backup_{1}.log" -f $Database, $Timestamp)

    Write-LogInfo "Backup root  : $BackupRoot"
    Write-LogInfo "Logs root    : $LogsRoot"
    Write-LogInfo "Log file     : $LogFile"
    Write-LogInfo "Database     : $Database"
    Write-LogInfo "User         : $UserName"
    if ($PSBoundParameters.ContainsKey('ModuleVersion')) {
        Write-LogInfo "Module ver   : $ModuleVersion (requested)"
    }

    # ----- Import the PostgresBackup module -----
    try {
        if ($PSBoundParameters.ContainsKey('ModuleVersion') -and $ModuleVersion) {
            Import-Module -Name PostgresBackup -RequiredVersion $ModuleVersion -ErrorAction Stop
        }
        else {
            Import-Module -Name PostgresBackup -ErrorAction Stop
        }
    }
    catch {
        Write-LogError "ERROR: Failed to import PostgresBackup module: $_"
        exit 1
    }

    # ----- Invoke backup -----
    try {
        Write-LogInfo "Starting backup via PostgresBackup::Backup-PostgresDatabase"
        Backup-PostgresDatabase `
            -dbname          $Database `
            -backup_folder   $BackupRoot `
            -log_file        $LogFile `
            -user            $UserName `
            -retention_days  $RetentionDays `
            -min_backups     $MinBackups

        # If the function throws, we won't reach here; success means exit code 0.
        Write-LogInfo "Backup completed successfully."
        Write-Output ([PSCustomObject]@{
                Database      = $Database
                BackupRoot    = $BackupRoot
                LogsRoot      = $LogsRoot
                LogFile       = $LogFile
                User          = $UserName
                RetentionDays = $RetentionDays
                MinBackups    = $MinBackups
                Status        = 'Success'
            })
        exit 0
    }
    catch {
        # The module also logs failures to $LogFile; we still surface a clear status/exit code here.
        Write-LogError "ERROR: Backup failed: $_"
        Write-Output ([PSCustomObject]@{
                Database      = $Database
                BackupRoot    = $BackupRoot
                LogsRoot      = $LogsRoot
                LogFile       = $LogFile
                User          = $UserName
                RetentionDays = $RetentionDays
                MinBackups    = $MinBackups
                Status        = 'Failed'
                Error         = $_.ToString()
            })
        exit 1
    }
}

try {
    Invoke-BackupMain
    exit 0
}
catch {
    $e = $_.Exception
    $innerMsg = ''
    if ($e -and $e.InnerException) { $innerMsg = $e.InnerException.Message }

    $msg = @(
        "Backup FAILED.",
        "Message: $($_.ToString())",
        "Type: $($e.GetType().FullName)",
        ("HResult: " + ('0x{0:X8}' -f $e.HResult)),
        ("Inner: " + $innerMsg),
        ("ScriptStack: " + $_.ScriptStackTrace),
        ("StackTrace: " + $e.StackTrace)
    ) -join "`r`n"
    Write-LogError $msg
    exit 1
}
