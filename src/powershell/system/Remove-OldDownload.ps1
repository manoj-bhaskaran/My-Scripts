<#PSScriptInfo
.VERSION 2.0.0
#>

<#
.SYNOPSIS
    Deletes files older than N days from a folder (default: Downloads), with robust logging.

.DESCRIPTION
    Removes files older than a given age threshold. Handles wildcard characters ([], ?, *)
    safely via -LiteralPath and long path issues (PS 5.1) via \\?\ prefix. Logs each attempt,
    surfaces real errors, and verifies removal. Supports WhatIf/Confirm, optional subfolder
    cleanup, and returns a summary object via -PassThru for programmatic use.

.PARAMETER FolderPath
    Folder to clean. Default: C:\Users\<you>\Downloads

.PARAMETER Days
    Files strictly older than (Now - Days) by LastWriteTime are deleted. Default: 14

.PARAMETER LogFilePath
    Path to the UTF-8 log file. The script creates the parent folder if missing.
    Default: C:\Users\manoj\Documents\Scripts\DeletedDownloadsLog.txt

.PARAMETER Recurse
    If specified, also delete matching files in subfolders.

.PARAMETER IncludeExtensions
    Optional list of file extensions (e.g., '.zip','.exe') to include. If omitted, all extensions are considered.

.PARAMETER ExcludeExtensions
    Optional list of file extensions to exclude.

.PARAMETER DeleteEmptyFolders
    If specified with -Recurse, deletes empty directories after file deletion (deepest-first).

.PARAMETER PassThru
    If specified, outputs a summary object with counts and ExitCode.

.EXAMPLE
    # Dry run with WhatIf
    .\DeleteOldDownloads.ps1 -Days 14 -FolderPath "$env:USERPROFILE\Downloads" -WhatIf

.EXAMPLE
    # Actual deletion with logging, return summary to pipeline
    .\DeleteOldDownloads.ps1 -Days 14 -Recurse -DeleteEmptyFolders -PassThru `
        -LogFilePath "C:\Users\manoj\Documents\Scripts\DeletedDownloadsLog.txt"

.NOTES
    VERSION: 2.0.0
    CHANGELOG:
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.2.1 - Previous version with custom Write-Log function

    Scheduling (Task Scheduler, recommended on PS 7+):
      Program/script:  C:\Program Files\PowerShell\7\pwsh.exe
      Arguments:       -NoProfile -ExecutionPolicy Bypass -File "C:\Users\manoj\Documents\Scripts\DeleteOldDownloads.ps1"
      Start in:        C:\Users\manoj\Documents\Scripts
      Options:         Run with highest privileges

    Exit codes:
      0 = Success (no failures)
      1 = Fatal script error
      2 = Completed with deletion failures (file and/or folder); see log

    Long paths:
      - PowerShell 7+ is long-path aware on modern Windows.
      - This script auto-applies \\?\ on Windows PowerShell 5.1 to avoid MAX_PATH issues.

    Logging:
      - Appends UTF-8 lines with timestamps and INFO/ERROR/WARN/DEBUG.
      - Verifies deletion with Test-Path and records the result.
#>

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName "DeleteOldDownloads" -LogLevel 20

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FolderPath = (Join-Path $env:USERPROFILE 'Downloads'),

    [Parameter()]
    [ValidateRange(1, 36500)]
    [int]$Days = 14,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LogFilePath = 'C:\Users\manoj\Documents\Scripts\DeletedDownloadsLog.txt',

    [Parameter()]
    [switch]$Recurse,

    [Parameter()]
    [string[]]$IncludeExtensions,

    [Parameter()]
    [string[]]$ExcludeExtensions,

    [Parameter()]
    [switch]$DeleteEmptyFolders,

    [Parameter()]
    [switch]$PassThru
)

#region --- Setup & Utilities ---

# Script version for logs (canonical version lives in PSScriptInfo header)
$Script:Version = '2.0.0'

# Detect legacy engine (Windows PowerShell 5.1) vs PowerShell 7+
$script:IsLegacyPS = $PSVersionTable.PSVersion.Major -lt 6

# Ensure log directory exists and the file is UTF-8
try {
    $logDir = Split-Path -Parent $LogFilePath
    if (-not [string]::IsNullOrEmpty($logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFilePath)) {
        "[{0}] [INFO] Log created" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Out-File -FilePath $LogFilePath -Encoding utf8
    }
}
catch {
    Write-Warning "Failed to prepare log file path '$LogFilePath': $($_.Exception.Message)"
}

# Removed custom Write-Log function - now using PowerShellLoggingFramework

# Add \\?\ extended path prefix on Windows PowerShell 5.1 to bypass MAX_PATH.
function Get-ExtendedLiteralPath {
    param([Parameter(Mandatory)][string]$Path)

    if (-not $script:IsLegacyPS) {
        return $Path
    }

    if ($Path.StartsWith('\\?\')) { return $Path }

    if ($Path.StartsWith('\\')) {
        # UNC -> \\?\UNC\server\share\...
        return ($Path -replace '^\\\\', '\\?\UNC\')
    }

    return '\\?\{0}' -f $Path
}

# Converts a list of extensions to a dot-prefixed list ('.zip' etc.)
function ConvertTo-ExtensionList {
    [CmdletBinding()]
    param([string[]]$List)

    if (-not $List) { return $null }

    return $List | ForEach-Object {
        if ($_ -match '^\.') { $_ } else { ".$_" }
    }
}

# Validate folder exists
if (-not (Test-Path -LiteralPath $FolderPath)) {
    Write-Error "Folder '$FolderPath' does not exist."
    Write-LogError "Folder '$FolderPath' does not exist."
    exit 1
}

# Normalize extension filters and compare in lowercase (explicitly case-insensitive)
$IncludeExtensions = ConvertTo-ExtensionList $IncludeExtensions
$ExcludeExtensions = ConvertTo-ExtensionList $ExcludeExtensions
if ($IncludeExtensions) { $IncludeExtensions = $IncludeExtensions | ForEach-Object { $_.ToLowerInvariant() } }
if ($ExcludeExtensions) { $ExcludeExtensions = $ExcludeExtensions | ForEach-Object { $_.ToLowerInvariant() } }

#endregion --- Setup & Utilities ---

#region --- Run Header ---

$engine = if ($script:IsLegacyPS) { 'Windows PowerShell' } else { 'PowerShell' }
$engineVer = $PSVersionTable.PSVersion.ToString()
$scriptName = $MyInvocation.MyCommand.Name
Write-LogInfo "===== $scriptName started | v$Script:Version | $engine $engineVer | Folder='$FolderPath' | Days=$Days | Recurse=$Recurse | DeleteEmptyFolders=$DeleteEmptyFolders ====="

#endregion --- Run Header ---

try {
    $now = Get-Date
    $cutoff = $now.AddDays(-$Days)

    # Build Get-ChildItem parameters
    $gciParams = @{
        LiteralPath = $FolderPath
        File        = $true
        Force       = $true
        ErrorAction = 'Stop'
    }
    if ($Recurse) { $gciParams.Recurse = $true }

    $allFiles = Get-ChildItem @gciParams

    # Filter by age
    $candidates = $allFiles | Where-Object { $_.LastWriteTime -lt $cutoff }

    # Optional: extension include/exclude (explicitly case-insensitive)
    if ($IncludeExtensions) {
        $candidates = $candidates | Where-Object { $IncludeExtensions -contains $_.Extension.ToLowerInvariant() }
    }
    if ($ExcludeExtensions) {
        $candidates = $candidates | Where-Object { $ExcludeExtensions -notcontains $_.Extension.ToLowerInvariant() }
    }

    $total = ($candidates | Measure-Object).Count
    $deleted = 0
    $failed = 0

    $removedDirs = 0
    $failedDirs = 0

    $inWhatIf = $WhatIfPreference -eq $true

    Write-LogInfo ("Found {0} candidate file(s) older than {1} days (cutoff: {2})" -f $total, $Days, $cutoff.ToString('yyyy-MM-dd HH:mm:ss'))

    if ($total -eq 0) {
        Write-LogInfo "No files to delete."
    }
    else {
        foreach ($file in $candidates) {
            $display = $file.FullName
            $msg = "Deleting: {0} | Last Modified: {1}" -f $display, $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            Write-LogInfo $msg

            if ($inWhatIf) {
                Write-LogDebug ("WhatIf: Would delete: {0}" -f $display)
                continue
            }

            if ($PSCmdlet.ShouldProcess($display, 'Remove file')) {
                # Prepare a literal path that is safe for both PS 5.1 and 7+
                $literalForOps = Get-ExtendedLiteralPath -Path $file.FullName

                try {
                    # Optional: clear ReadOnly so -Force isn't the only lever
                    if ($file.Attributes -band [IO.FileAttributes]::ReadOnly) {
                        try {
                            Set-ItemProperty -LiteralPath $literalForOps -Name Attributes -Value ([IO.FileAttributes]::Normal) -ErrorAction SilentlyContinue
                        }
                        catch {
                            Write-LogDebug "Failed to clear ReadOnly attribute for ${literalForOps}: $_"
                        }
                    }

                    # Perform deletion with hard error on failure
                    Remove-Item -LiteralPath $literalForOps -Force -ErrorAction Stop

                    # Verify removal
                    if (Test-Path -LiteralPath $literalForOps) {
                        Write-LogError ("FAILED (still exists after delete): {0}" -f $display)
                        $failed++
                    }
                    else {
                        Write-LogInfo ("Deleted OK: {0}" -f $display)
                        $deleted++
                    }
                }
                catch {
                    Write-LogError ("FAILED: {0}`n  Error: {1}" -f $display, $_.Exception.Message)
                    $failed++
                }
            }
        }
    }

    # Optionally delete empty subfolders (deepest-first)
    if ($Recurse -and $DeleteEmptyFolders) {
        Write-LogInfo "Scanning for empty folders to remove..."
        $dirs = Get-ChildItem -LiteralPath $FolderPath -Directory -Recurse -Force -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending

        foreach ($dir in $dirs) {
            $dirDisplay = $dir.FullName
            $dirPath = Get-ExtendedLiteralPath -Path $dir.FullName

            if ($inWhatIf) {
                Write-LogDebug ("WhatIf: Would remove empty folder: {0}" -f $dirDisplay)
                continue
            }

            # Determine emptiness via enumerator; log WARN on enumeration errors
            $dirIsEmpty = $false
            try {
                $e = [System.IO.Directory]::EnumerateFileSystemEntries($dirPath).GetEnumerator()
                $dirIsEmpty = -not $e.MoveNext()
            }
            catch {
                Write-LogWarning ("Unable to enumerate directory: {0}`n  Error: {1}" -f $dirDisplay, $_.Exception.Message)
                $failedDirs++
                $dirIsEmpty = $false
            }

            if ($dirIsEmpty -and $PSCmdlet.ShouldProcess($dirDisplay, 'Remove empty directory')) {
                try {
                    Remove-Item -LiteralPath $dirPath -Force -ErrorAction Stop
                    Write-LogInfo ("Removed empty folder: {0}" -f $dirDisplay)
                    $removedDirs++
                }
                catch {
                    Write-LogError ("FAILED to remove folder: {0}`n  Error: {1}" -f $dirDisplay, $_.Exception.Message)
                    $failedDirs++
                }
            }
        }
    }

    # Final summary + unified PassThru object and exit code
    Write-LogInfo ("Summary: Candidates={0}, Deleted={1}, Failed={2}, EmptyFoldersRemoved={3}, EmptyFolderFailures={4}" -f `
            $total, $deleted, $failed, $removedDirs, $failedDirs)
    Write-LogInfo "===== $scriptName ended ====="

    $exitCode = if ( ($failed -gt 0) -or ($failedDirs -gt 0) ) { 2 } else { 0 }

    if ($PassThru) {
        [pscustomobject]@{
            Version             = $Script:Version
            Candidates          = $total
            Deleted             = $deleted
            Failed              = $failed
            EmptyFoldersRemoved = $removedDirs
            EmptyFolderFailures = $failedDirs
            ExitCode            = $exitCode
        }
    }

    exit $exitCode
}
catch {
    Write-LogError ("FATAL: {0}" -f $_.Exception.ToString())
    Write-Error $_
    exit 1
}
