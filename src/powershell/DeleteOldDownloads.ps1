<#
<#PSScriptInfo
.VERSION 1.1
#>
<#
.SYNOPSIS
    Deletes files older than N days from a folder (default: Downloads), with robust logging.

.DESCRIPTION
    This script removes files older than a given age threshold.
    It fixes two common pitfalls:
      1) Wildcard characters like [ ] ? * in filenames by using -LiteralPath everywhere.
      2) Legacy MAX_PATH issues by adding \\?\ extended prefix automatically on Windows PowerShell 5.1.

    It logs each attempt, captures real error messages on failures, and verifies removal.
    Compatible with Windows PowerShell 5.1 and PowerShell 7+ (recommended).

.PARAMETER FolderPath
    Folder to clean. Default: C:\Users\<you>\Downloads

.PARAMETER Days
    Files strictly older than (Now - Days) by LastWriteTime are deleted.
    Default: 14

.PARAMETER LogFilePath
    Path to the UTF-8 log file. The script creates the parent folder if missing.
    Default: C:\Users\manoj\Documents\Scripts\DeletedDownloadsLog.txt

.PARAMETER Recurse
    If specified, also delete matching files in subfolders.

.PARAMETER IncludeExtensions
    Optional list of file extensions (e.g., '.zip','.exe') to include. If omitted, all extensions are considered.

.PARAMETER ExcludeExtensions
    Optional list of file extensions to exclude.

.EXAMPLE
    # Dry run with WhatIf
    .\DeleteOldDownloads.ps1 -Days 14 -FolderPath "$env:USERPROFILE\Downloads" -WhatIf

.EXAMPLE
    # Actual deletion with logging
    .\DeleteOldDownloads.ps1 -Days 14 -FolderPath "$env:USERPROFILE\Downloads" `
        -LogFilePath "C:\Users\manoj\Documents\Scripts\DeletedDownloadsLog.txt"

.NOTES
    Scheduling (Task Scheduler, recommended on PS 7+):
      Program/script:  C:\Program Files\PowerShell\7\pwsh.exe
      Arguments:       -NoProfile -ExecutionPolicy Bypass -File "C:\Users\manoj\Documents\Scripts\DeleteOldDownloads.ps1"
      Start in:        C:\Users\manoj\Documents\Scripts
      Options:         Run with highest privileges

    Long paths:
      - PowerShell 7+ is long-path aware on modern Windows.
      - This script still auto-applies \\?\ on Windows PowerShell 5.1 to avoid MAX_PATH issues.

    Logging:
      - Appends UTF-8 lines with timestamps and INFO/ERROR levels.
      - Verifies deletion with Test-Path and records the result.
#>

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
    [string[]]$ExcludeExtensions
)

#region --- Setup & Utilities ---

# Detect legacy engine (Windows PowerShell 5.1) vs PowerShell 7+
$script:IsLegacyPS = $PSVersionTable.PSVersion.Major -lt 6

# Ensure log directory exists and the file is UTF-8
try {
    $logDir = Split-Path -Parent $LogFilePath
    if ($logDir) { New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null }
    if (-not (Test-Path -LiteralPath $LogFilePath)) {
        # Create with header in UTF-8
        "[{0}] [INFO] Log created" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Out-File -FilePath $LogFilePath -Encoding utf8
    }
}
catch {
    Write-Warning "Failed to prepare log file path '$LogFilePath': $($_.Exception.Message)"
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','ERROR','WARN','DEBUG')]
        [string]$Level = 'INFO'
    )
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    try {
        Add-Content -Path $LogFilePath -Value "[$ts] [$Level] $Message"
    }
    catch {
        Write-Warning "Log write failed: $($_.Exception.Message)"
    }
}

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

# Normalize extension lists (ensure they start with a dot)
function ConvertTo-ExtensionList {
    param([string[]]$List)
    if (-not $List) { return $null }
    return $List | ForEach-Object {
        if ($_ -match '^\.') { $_ } else { ".$_" }
    }
}

# Validate folder exists
if (-not (Test-Path -LiteralPath $FolderPath)) {
    Write-Error "Folder '$FolderPath' does not exist."
    Write-Log  "Folder '$FolderPath' does not exist." 'ERROR'
    exit 1
}

# Normalize extension filters
$IncludeExtensions = ConvertTo-ExtensionList $IncludeExtensions
$ExcludeExtensions = ConvertTo-ExtensionList $ExcludeExtensions

#endregion --- Setup & Utilities ---

#region --- Run Header ---

$engine = if ($script:IsLegacyPS) { 'Windows PowerShell' } else { 'PowerShell' }
$engineVer = $PSVersionTable.PSVersion.ToString()
$scriptName = if ($PSCommandPath) { Split-Path -Leaf $PSCommandPath } else { 'DeleteOldDownloads.ps1' }
Write-Log "===== $scriptName started | $engine $engineVer | Folder='$FolderPath' | Days=$Days | Recurse=$Recurse ====="

#endregion --- Run Header ---

try {
    $now    = Get-Date
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

    # Optional: extension include/exclude
    if ($IncludeExtensions) {
        $candidates = $candidates | Where-Object { $IncludeExtensions -contains $_.Extension }
    }
    if ($ExcludeExtensions) {
        $candidates = $candidates | Where-Object { $ExcludeExtensions -notcontains $_.Extension }
    }

    $total = ($candidates | Measure-Object).Count
    Write-Log ("Found {0} candidate file(s) older than {1} days (cutoff: {2})" -f $total, $Days, $cutoff.ToString('yyyy-MM-dd HH:mm:ss'))

    if ($total -eq 0) {
        Write-Log "No files to delete. Exiting."
        Write-Log "===== $scriptName ended ====="
        exit 0
    }

    $deleted = 0
    $failed  = 0

    foreach ($file in $candidates) {
        $display = $file.FullName
        $msg = "Deleting: {0} | Last Modified: {1}" -f $display, $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        Write-Log $msg

        if ($PSCmdlet.ShouldProcess($display, 'Remove file')) {
            # Prepare a literal path that is safe for both PS 5.1 and 7+
            $literalForOps = Get-ExtendedLiteralPath -Path $file.FullName

            try {
                # Optional: clear ReadOnly so -Force isn't the only lever
                if ($file.Attributes -band [IO.FileAttributes]::ReadOnly) {
                    try {
                        # Best-effort attribute clear
                        Set-ItemProperty -LiteralPath $literalForOps -Name Attributes -Value ([IO.FileAttributes]::Normal) -ErrorAction SilentlyContinue
                    } catch { }
                }

                # Perform deletion with hard error on failure
                Remove-Item -LiteralPath $literalForOps -Force -ErrorAction Stop

                # Verify removal
                if (Test-Path -LiteralPath $literalForOps) {
                    Write-Log ("FAILED (still exists after delete): {0}" -f $display) 'ERROR'
                    $failed++
                } else {
                    Write-Log ("Deleted OK: {0}" -f $display)
                    $deleted++
                }
            }
            catch {
                Write-Log ("FAILED: {0}`n  Error: {1}" -f $display, $_.Exception.Message) 'ERROR'
                $failed++
            }
        }
        else {
            # WhatIf path
            Write-Log ("WhatIf: Would delete: {0}" -f $display) 'DEBUG'
        }
    }

    Write-Log ("Summary: Candidates={0}, Deleted={1}, Failed={2}" -f $total, $deleted, $failed)
    Write-Log "===== $scriptName ended ====="

    if ($failed -gt 0 -and -not $PSBoundParameters.ContainsKey('WhatIf')) {
        exit 2
    }
    else {
        exit 0
    }
}
catch {
    Write-Log ("FATAL: {0}" -f $_.Exception.ToString()) 'ERROR'
    Write-Error $_
    exit 1
}
