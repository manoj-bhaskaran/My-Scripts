<#
.SYNOPSIS
    Backs up the `job_scheduler` PostgreSQL database using the `PostgresBackup` module.
.DESCRIPTION
    This script performs a backup of the `job_scheduler` PostgreSQL database, designed for execution via Windows Task Scheduler. 
    It uses the `backup_user` account with a `.pgpass` file for secure password management and logs all operations to a timestamped 
    log file with a standardized timestamp format `[YYYYMMDD-HHMMSS]`. The script uses the `PostgresBackup` PowerShell module (version 1.0.3 or higher) 
    and writes all log entries directly to the timestamped log file in chronological order. The script ensures the backup directory exists and sets 
    appropriate exit codes for Task Scheduler (0 for success, 1 for failure).
.PREREQUISITES
    - PostgreSQL and `pg_dump` (version 17 or compatible) installed at `D:\Program Files\PostgreSQL\17\bin\pg_dump.exe`.
    - `PostgresBackup` module (version 1.0.3 or higher) installed at `C:\Program Files\WindowsPowerShell\Modules\PostgresBackup\1.0.3\PostgresBackup.psm1` with a manifest (`PostgresBackup.psd1`).
    - A `.pgpass` file configured for `backup_user` at `%APPDATA%\postgresql\pgpass.conf` (e.g., 
      `C:\Users\<ServiceAccount>\AppData\Roaming\postgresql\pgpass.conf`) with the entry:
      `localhost:5432:job_scheduler:backup_user:<password>`
    - The `.pgpass` file must have restricted permissions (accessible only to the Task Scheduler service account).
    - The Task Scheduler service account must have read access to the `PostgresBackup` module and write access to the backup folder (`D:\pgbackup\job_scheduler`).
.EXAMPLE
    powershell.exe -File .\job_scheduler_pg_backup.ps1
    Runs the script to back up the `job_scheduler` database, creating a backup and log file in `D:\pgbackup\job_scheduler`.
.NOTES
    - Logs are written to a timestamped file (`job_scheduler_backup_YYYYMMDD-HHMMSS.log`) in the backup folder with timestamps in `[YYYYMMDD-HHMMSS]` format, in chronological order.
    - The script relies on `.pgpass` for authentication, as the `PostgresBackup` module supports empty passwords.
    - Exit codes: 0 (success), 1 (failure).
    - The `PostgresBackup` module replaces the previous `pg_backup_common.ps1` dependency to eliminate path issues.
#>

# Licensed under the Apache License, Version 2.0
# See http://www.apache.org/licenses/LICENSE-2.0 for details

# Backup script for the `job_scheduler` PostgreSQL database
# Uses `PostgresBackup` module for backup functionality
# Designed for Windows Task Scheduler, logs all output to a file
# Uses `.pgpass` for secure password management with `backup_user`

# Get the script's directory for logging purposes
$ScriptDir = if ($MyInvocation.MyCommand.Path) { 
    Split-Path -Parent $MyInvocation.MyCommand.Path 
} elseif ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Get-Location | Select-Object -ExpandProperty Path
}

if (-not $ScriptDir) {
    Write-Error "ERROR: Unable to determine script directory"
    exit 1
}

# Configuration
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$DatabaseName = "job_scheduler"
$OutputFolder = "D:\pgbackup\job_scheduler"
$LogFile = Join-Path $OutputFolder "job_scheduler_backup_$Timestamp.log"
$User = "backup_user"
$ModuleBasePath = "C:\Program Files\WindowsPowerShell\Modules\PostgresBackup"
$ModuleVersion = "1.0.3"
$ModulePath = Join-Path $ModuleBasePath "$ModuleVersion\PostgresBackup.psm1"
$ManifestPath = Join-Path $ModuleBasePath "$ModuleVersion\PostgresBackup.psd1"

# Validate and create backup directory
if (-not (Test-Path $OutputFolder -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $OutputFolder -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "ERROR: Cannot create backup directory `$OutputFolder`: $_"
        exit 1
    }
}

# Log script start
try {
    Add-Content -Path $LogFile -Value "[$Timestamp] Starting job_scheduler backup" -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$Timestamp] Script directory: $ScriptDir" -ErrorAction Stop
    Add-Content -Path $LogFile -Value "[$Timestamp] Backup directory: $OutputFolder" -ErrorAction Stop
} catch {
    Write-Error "ERROR: Cannot write to log file `$LogFile`: $_"
    exit 1
}

# Function to validate module content
function Test-ModuleContent {
    param (
        [string]$ModulePath
    )
    try {
        $moduleContent = Get-Content -Path $ModulePath -Raw
        $hasLogFileParam = $moduleContent -match '\[Parameter\(Mandatory=\$true\)]\s*\[string\]\$log_file'
        $hasCorrectTimestamp = $moduleContent -match '\$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"'
        return $hasLogFileParam -and $hasCorrectTimestamp
    } catch {
        Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Failed to read module content at `$ModulePath`: $_" -ErrorAction Stop
        return $false
    }
}

# Function to validate log file entries
function Test-LogEntries {
    param (
        [string]$LogFile
    )
    try {
        $logContent = Get-Content -Path $LogFile
        $malformedEntries = $logContent | Where-Object { $_ -match '\[\s*\d\s*\d\s*\d\s*\d\s*-\s*\d\s*\d\s*\d\s*\d\s*\]' }
        if ($malformedEntries) {
            Add-Content -Path $LogFile -Value "[$Timestamp] WARNING: Malformed log entries detected with spaces in timestamps:" -ErrorAction Stop
            $malformedEntries | ForEach-Object { Add-Content -Path $LogFile -Value "[$Timestamp] Malformed entry: $_" -ErrorAction Stop }
        }
    } catch {
        Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Failed to validate log entries in `$LogFile`: $_" -ErrorAction Stop
    }
}

# Import PostgresBackup module and verify version
try {
    Import-Module PostgresBackup -MinimumVersion $ModuleVersion -Force -ErrorAction Stop
    $module = Get-Module PostgresBackup
    Add-Content -Path $LogFile -Value "[$Timestamp] PostgresBackup module (version $($module.Version)) imported successfully" -ErrorAction Stop
    # Verify module content
    if (-not (Test-ModuleContent -ModulePath $ModulePath)) {
        Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: PostgresBackup module at `$ModulePath` does not support log_file parameter or correct timestamp format" -ErrorAction Stop
        exit 1
    }
} catch {
    $modulePaths = $env:PSModulePath -split ";"
    $availableModules = Get-Module -ListAvailable PostgresBackup | ForEach-Object { "Version $($_.Version) at $($_.ModuleBase)" }
    $errorDetails = "[$Timestamp] ERROR: Failed to import PostgresBackup module (version $ModuleVersion or higher required). Module paths searched: $($modulePaths -join ', '). Available versions: $(if ($availableModules) { $availableModules -join ', ' } else { 'None' })."
    
    # Check versioned directory
    $versionedDir = Join-Path $ModuleBasePath $ModuleVersion
    if (Test-Path $versionedDir) {
        $errorDetails += " Versioned directory found at `$versionedDir`."
    } else {
        $errorDetails += " Versioned directory not found at `$versionedDir`. Ensure module is deployed correctly."
    }
    
    # Check module file
    if (Test-Path $ModulePath) {
        try {
            $moduleContent = Get-Content -Path $ModulePath -Head 20 -ErrorAction Stop
            $versionLine = $moduleContent | Where-Object { $_ -match "Version: (\d+\.\d+\.\d+)" }
            $errorDetails += " Module file found at `$ModulePath`. Version comment: $(if ($versionLine) { $versionLine } else { 'Not found' })."
            if (-not (Test-ModuleContent -ModulePath $ModulePath)) {
                $errorDetails += " Module does not support log_file parameter or correct timestamp format."
            }
        } catch {
            $errorDetails += " Module file found at `$ModulePath`, but failed to read content: $_."
        }
    } else {
        $errorDetails += " Module file not found at `$ModulePath`."
    }
    
    # Check manifest
    if (Test-Path $ManifestPath) {
        try {
            $manifestContent = Import-PowerShellDataFile -Path $ManifestPath -ErrorAction Stop
            $manifestVersion = $manifestContent.ModuleVersion
            $rootModule = $manifestContent.RootModule
            $errorDetails += " Manifest found at `$ManifestPath`. Manifest version: $(if ($manifestVersion) { $manifestVersion } else { 'Not specified' }). RootModule: $(if ($rootModule) { $rootModule } else { 'Not specified' })."
        } catch {
            $errorDetails += " Manifest found at `$ManifestPath`, but failed to read content: $_."
        }
    } else {
        $errorDetails += " Manifest not found at `$ManifestPath`. Consider creating one with ModuleVersion = '$ModuleVersion'."
    }
    
    $errorDetails += " Error: $_"
    Add-Content -Path $LogFile -Value $errorDetails -ErrorAction Stop
    
    # Fallback: Attempt to load module explicitly
    if (Test-Path $ModulePath) {
        try {
            Import-Module $ModulePath -Force -ErrorAction Stop
            $module = Get-Module PostgresBackup
            $manifestVersion = if ($module.Version -eq "0.0") { "Unknown (no valid manifest or version 0.0)" } else { $module.Version }
            Add-Content -Path $LogFile -Value "[$Timestamp] WARNING: Loaded PostgresBackup module (version $manifestVersion) from `$ModulePath`, but version $ModuleVersion or higher with log_file parameter is required" -ErrorAction Stop
            if (-not (Test-ModuleContent -ModulePath $ModulePath)) {
                Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Fallback PostgresBackup module at `$ModulePath` does not support log_file parameter or correct timestamp format" -ErrorAction Stop
                exit 1
            }
        } catch {
            Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Fallback import of PostgresBackup module from `$ModulePath` failed: $_" -ErrorAction Stop
            exit 1
        }
    } else {
        Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: No PostgresBackup module found at `$ModulePath` or in module paths" -ErrorAction Stop
        exit 1
    }
}

# Verify Backup-PostgresDatabase function is available
if (-not (Get-Command -Name Backup-PostgresDatabase -ErrorAction SilentlyContinue)) {
    Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Backup-PostgresDatabase function not found in PostgresBackup module" -ErrorAction Stop
    exit 1
}

# Verify log_file parameter support
$command = Get-Command -Name Backup-PostgresDatabase -ErrorAction SilentlyContinue
if ($command -and -not $command.Parameters.ContainsKey('log_file')) {
    Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Backup-PostgresDatabase does not support log_file parameter, required for direct logging" -ErrorAction Stop
    exit 1
}

# Run the backup
try {
    Backup-PostgresDatabase -dbname $DatabaseName -backup_folder $OutputFolder -log_file $LogFile -user $User -retention_days 90 -min_backups 3
    if ($LASTEXITCODE -eq 0) {
        Add-Content -Path $LogFile -Value "[$Timestamp] Backup completed successfully" -ErrorAction Stop
        # Validate log entries
        Test-LogEntries -LogFile $LogFile
        exit 0
    } else {
        Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Backup failed with exit code $LASTEXITCODE" -ErrorAction Stop
        Test-LogEntries -LogFile $LogFile
        exit 1
    }
} catch {
    Add-Content -Path $LogFile -Value "[$Timestamp] ERROR: Backup failed: $_" -ErrorAction Stop
    Test-LogEntries -LogFile $LogFile
    exit 1
}