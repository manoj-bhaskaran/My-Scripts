<#
 .VERSION
     1.6
.SYNOPSIS
    Runs a PostgreSQL backup for the job_scheduler database via the PostgresBackup module.

.DESCRIPTION
    - Ensures backup and log folders exist under:
        D:\pgbackup\job_scheduler\
        D:\pgbackup\job_scheduler\logs
    - Builds a timestamped log file in the logs folder and passes it to the module.
    - Imports the PostgresBackup module (highest available version on PSModulePath).
    - Invokes Backup-PostgresDatabase with retention defaults.
    - Returns exit code 0 on success, 1 on failure (Task Scheduler friendly).

.NOTES

Authentication uses .pgpass for backup_user. A dummy invalid password is set via:
  $DummyPassword = ConvertTo-SecureString "invalid" -AsPlainText -Force
This satisfies pg_backup_common.ps1 while keeping actual auth on .pgpass.
    Requires:
      - PostgresBackup module deployed/available on PSModulePath
      - .pgpass (or equivalent) if running with empty password
    Author: Manoj Bhaskaran
    Last Updated: 2025-08-16
#>
[CmdletBinding()]
param(
    # Override defaults if needed when calling from Task Scheduler
    [string]$Database       = 'job_scheduler',
    [string]$BackupRoot     = 'D:\pgbackup\job_scheduler',          # where .backup files go
    [string]$LogsRoot       = 'D:\pgbackup\job_scheduler\logs',      # where .log files go
    [string]$UserName       = 'backup_user',                         # PG user
    [int]   $RetentionDays  = 90,
    [int]   $MinBackups     = 3,

    # If you want to force a specific PostgresBackup version, set this (e.g., '1.0.4')
    [string]$ModuleVersion
)
# === Preflight & Hardening (v1.6) ===
$ErrorActionPreference = 'Stop'

# Rich diagnostics on any unhandled terminating error
trap {
    try {
        $e = $_.Exception
        $msg = @(
            "Backup FAILED.",
            "Message: $($_.ToString())",
            "Type: $($e.GetType().FullName)",
            ("HResult: " + ('0x{0:X8}' -f $e.HResult)),
            ("Inner: " + ($e.InnerException?.Message)),
            ("ScriptStack: " + $_.ScriptStackTrace),
            ("StackTrace: " + $e.StackTrace)
        ) -join "`r`n"
        Write-Error $msg
    } catch {
        Write-Error ("Backup FAILED. " + $_.ToString())
    }
    exit 2
}

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
} catch {
    Write-Warning "Could not inspect ACLs for .pgpass at '$PgPass': $($_.Exception.Message)"
}
# === End Preflight ===

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ----- Helpers -----
function New-DirectoryIfMissing {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-HostInfo {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$ts] $Message"
}

# ----- Ensure folders -----
try {
    New-DirectoryIfMissing -Path $BackupRoot
    New-DirectoryIfMissing -Path $LogsRoot
} catch {
    Write-HostInfo "ERROR: Failed to ensure backup/log directories: $_"
    exit 1
}

# ----- Build timestamped log path (module will append UTF-8) -----
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile   = Join-Path $LogsRoot ("{0}_backup_{1}.log" -f $Database, $Timestamp)

Write-HostInfo "Backup root  : $BackupRoot"
Write-HostInfo "Logs root    : $LogsRoot"
Write-HostInfo "Log file     : $LogFile"
Write-HostInfo "Database     : $Database"
Write-HostInfo "User         : $UserName"
if ($PSBoundParameters.ContainsKey('ModuleVersion')) {
    Write-HostInfo "Module ver   : $ModuleVersion (requested)"
}

# ----- Import the PostgresBackup module -----
try {
    if ($PSBoundParameters.ContainsKey('ModuleVersion') -and $ModuleVersion) {
        Import-Module -Name PostgresBackup -RequiredVersion $ModuleVersion -ErrorAction Stop
    } else {
        Import-Module -Name PostgresBackup -ErrorAction Stop
    }
} catch {
    Write-HostInfo "ERROR: Failed to import PostgresBackup module: $_"
    exit 1
}

# ----- Build password (empty → .pgpass auth) -----
# Leave empty to rely on .pgpass; change here if you want to pass a real password.
$SecurePwd = ConvertTo-SecureString "invalid" -AsPlainText -Force

# ----- Invoke backup -----
try {
    Write-HostInfo "Starting backup via PostgresBackup::Backup-PostgresDatabase"
    Backup-PostgresDatabase `
        -dbname          $Database `
        -backup_folder   $BackupRoot `
        -log_file        $LogFile `
        -user            $UserName `
        -password        $SecurePwd `
        -retention_days  $RetentionDays `
        -min_backups     $MinBackups

    # If the function throws, we won't reach here; success means exit code 0.
    Write-HostInfo "Backup completed successfully."
    exit 0
} catch {
    # The module also logs failures to $LogFile; we still surface a clear status/exit code here.
    Write-HostInfo "ERROR: Backup failed: $_"
    exit 1
}
