<#PSScriptInfo
.VERSION 1.3.0
#>

<#
.SYNOPSIS
    Copies files with predefined extensions from a source folder to a destination
    folder, then deletes the originals from the source.

.DESCRIPTION
    Scans a source folder (optionally recursively) for files whose extensions match
    a configurable list, copies them to a destination folder, and deletes the
    originals based on the chosen delete mode.

    Configuration can be provided via command-line parameters or via .env variables
    in the repository root. Parameters always take precedence over .env values.

.PARAMETER SourceFolder
    Path to the folder to scan for files.
    Overrides env var: COPY_EXT_SOURCE

.PARAMETER DestinationFolder
    Path to the folder where matching files will be copied.
    Overrides env var: COPY_EXT_DEST

.PARAMETER Extensions
    One or more file extensions to copy (e.g. '.jpg', '.png', 'mp4').
    Leading dots are optional and case is ignored.
    Overrides env var: COPY_EXT_EXTENSIONS (comma-separated, e.g. jpg,png,mp4)

.PARAMETER Recurse
    Scan subfolders of the source recursively.
    Overrides env var: COPY_EXT_RECURSE (true/false, default: false)

.PARAMETER ConflictMode
    How to handle a filename collision in the destination folder.
    - Rename    Append an incrementing suffix (_1, _2, …) to the copy (default).
    - Skip      Leave the source file untouched and skip it.
    - Overwrite Replace the existing destination file.
    Overrides env var: COPY_EXT_CONFLICT_MODE

.PARAMETER DeleteMode
    How to handle the source file after a successful copy.
    - Immediate   Delete the source file immediately (default).
    - RecycleBin  Send the source file to the Windows Recycle Bin.
    - None        Do not delete the source file.
    Overrides env var: COPY_EXT_DELETE_MODE

.PARAMETER PassThru
    Return a summary object to the pipeline when the script finishes.
    When this switch is NOT specified, a human-readable diagnostics summary is
    written to the console (host) instead.

.EXAMPLE
    # Copy .jpg and .png from D:\Photos\Inbox to D:\Photos\Sorted, delete originals
    .\Copy-FilesByExtension.ps1 -SourceFolder D:\Photos\Inbox `
        -DestinationFolder D:\Photos\Sorted -Extensions jpg,png

.EXAMPLE
    # Dry run (no files are actually copied or deleted)
    .\Copy-FilesByExtension.ps1 -SourceFolder D:\Inbox -DestinationFolder D:\Sorted `
        -Extensions pdf,docx -WhatIf

.EXAMPLE
    # Read all settings from .env, send deleted files to Recycle Bin
    .\Copy-FilesByExtension.ps1 -DeleteMode RecycleBin

.NOTES
    VERSION: 1.3.0
    CHANGELOG:
        1.3.0 - Write diagnostics/statistics to the console when not in PassThru mode
        1.2.0 - Fix -Recurse:$false not overriding COPY_EXT_RECURSE (use
                PSBoundParameters instead of IsPresent); validate ConflictMode and
                DeleteMode when sourced from .env; exclude destination subtree from
                recursive enumeration to prevent re-processing already-copied files
        1.1.0 - Flatten comma-separated values in -Extensions parameter
        1.0.0 - Initial release

    .env variables (all optional when the equivalent parameter is supplied):
        COPY_EXT_SOURCE         Source folder path
        COPY_EXT_DEST           Destination folder path
        COPY_EXT_EXTENSIONS     Comma-separated extensions, e.g. jpg,png,.mp4
        COPY_EXT_RECURSE        true | false  (default: false)
        COPY_EXT_CONFLICT_MODE  Rename | Skip | Overwrite  (default: Rename)
        COPY_EXT_DELETE_MODE    Immediate | RecycleBin | None  (default: Immediate)

    Exit codes:
        0  Success – all files copied (and deleted, if applicable) without error.
        1  Fatal error or invalid / missing configuration.
        2  Completed with one or more copy or delete failures; see log.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [string]$SourceFolder,

    [Parameter()]
    [string]$DestinationFolder,

    [Parameter()]
    [string[]]$Extensions,

    [Parameter()]
    [switch]$Recurse,

    [Parameter()]
    [ValidateSet('Rename', 'Skip', 'Overwrite')]
    [string]$ConflictMode,

    [Parameter()]
    [ValidateSet('Immediate', 'RecycleBin', 'None')]
    [string]$DeleteMode,

    [Parameter()]
    [switch]$PassThru
)

#region ── Logging framework ────────────────────────────────────────────────────
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force
Initialize-Logger -ScriptName 'CopyFilesByExtension' -LogLevel 20
#endregion

$Script:Version = '1.3.0'
$script:Copied = 0
$script:Skipped = 0
$script:Failed = 0
$script:Deleted = 0
$script:DelFailed = 0

#region ── Load .env ────────────────────────────────────────────────────────────
$envFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\..\.env"))
if (-not (Test-Path $envFile)) {
    # Fallback: walk up from script root until we find .env or run out of parents
    $searchDir = $PSScriptRoot
    for ($i = 0; $i -lt 6; $i++) {
        $searchDir = Split-Path $searchDir -Parent
        if (-not $searchDir) { break }
        $candidate = Join-Path $searchDir '.env'
        if (Test-Path $candidate) { $envFile = $candidate; break }
    }
}

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\s*#' -or $line -eq '') { return }
        if ($line -match '^([^=]+)=(.*)$') {
            $n = $matches[1].Trim()
            $v = $matches[2].Trim() -replace '^["''"]|["''"]$', ''
            [Environment]::SetEnvironmentVariable($n, $v, 'Process')
        }
    }
    Write-LogDebug "Loaded .env from '$envFile'"
}
else {
    Write-LogDebug '.env file not found – using parameters only.'
}
#endregion

#region ── Resolve configuration (parameter overrides .env) ─────────────────────
if (-not $SourceFolder) { $SourceFolder = $env:COPY_EXT_SOURCE }
if (-not $DestinationFolder) { $DestinationFolder = $env:COPY_EXT_DEST }

if (-not $Extensions) {
    $raw = $env:COPY_EXT_EXTENSIONS
    if ($raw) {
        $Extensions = $raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    }
}

if (-not $PSBoundParameters.ContainsKey('Recurse')) {
    if ($env:COPY_EXT_RECURSE -match '^(1|true|yes)$') { $Recurse = $true }
}

if (-not $ConflictMode) {
    $ConflictMode = if ($env:COPY_EXT_CONFLICT_MODE) { $env:COPY_EXT_CONFLICT_MODE } else { 'Rename' }
}

if (-not $DeleteMode) {
    $DeleteMode = if ($env:COPY_EXT_DELETE_MODE) { $env:COPY_EXT_DELETE_MODE } else { 'Immediate' }
}

# Validate enum values that may have come from .env (not covered by [ValidateSet])
$validConflictModes = @('Rename', 'Skip', 'Overwrite')
if ($ConflictMode -notin $validConflictModes) {
    $msg = "Invalid ConflictMode '$ConflictMode'. Must be one of: $($validConflictModes -join ', ')."
    Write-LogError $msg; Write-Error $msg; exit 1
}
$validDeleteModes = @('Immediate', 'RecycleBin', 'None')
if ($DeleteMode -notin $validDeleteModes) {
    $msg = "Invalid DeleteMode '$DeleteMode'. Must be one of: $($validDeleteModes -join ', ')."
    Write-LogError $msg; Write-Error $msg; exit 1
}
#endregion

#region ── Validate ──────────────────────────────────────────────────────────────
$missingConfig = @()
if (-not $SourceFolder) { $missingConfig += 'SourceFolder (or env COPY_EXT_SOURCE)' }
if (-not $DestinationFolder) { $missingConfig += 'DestinationFolder (or env COPY_EXT_DEST)' }
if (-not $Extensions) { $missingConfig += 'Extensions (or env COPY_EXT_EXTENSIONS)' }

if ($missingConfig.Count -gt 0) {
    $msg = "Missing required configuration: $($missingConfig -join '; ')"
    Write-LogError $msg
    Write-Error $msg
    exit 1
}

if (-not (Test-Path -LiteralPath $SourceFolder)) {
    $msg = "Source folder not found: '$SourceFolder'"
    Write-LogError $msg
    Write-Error $msg
    exit 1
}

# Resolve both paths to absolute form once (GetFullPath works even if dest doesn't exist yet)
$resolvedSource = [System.IO.Path]::GetFullPath($SourceFolder).TrimEnd('\')
$resolvedDest = [System.IO.Path]::GetFullPath($DestinationFolder).TrimEnd('\')

# Detect when destination is nested inside the source tree (relevant for -Recurse)
$destIsUnderSource = $resolvedDest.StartsWith($resolvedSource + '\', [System.StringComparison]::OrdinalIgnoreCase)
if ($destIsUnderSource -and $Recurse) {
    Write-LogInfo "Note: destination '$resolvedDest' is inside the source tree – its files will be excluded from enumeration."
}

# Normalise extensions: split any comma-separated items, lowercase, add leading dot
$Extensions = $Extensions |
    ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim().ToLowerInvariant() } |
    Where-Object { $_ -ne '' } |
    ForEach-Object { if ($_ -notmatch '^\.' ) { ".$_" } else { $_ } }
#endregion

#region ── Helpers ──────────────────────────────────────────────────────────────
function Remove-ToRecycleBin {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    Add-Type -AssemblyName Microsoft.VisualBasic

    if ($PSCmdlet.ShouldProcess($FilePath, 'Move to Recycle Bin')) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            $FilePath,
            'OnlyErrorDialogs',
            'SendToRecycleBin'
        )
    }
}

function Get-UniqueDestPath {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$FileName
    )
    $base = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext = [IO.Path]::GetExtension($FileName)
    $dest = Join-Path $Directory $FileName
    $index = 1
    while (Test-Path -LiteralPath $dest) {
        $dest = Join-Path $Directory "${base}_${index}${ext}"
        $index++
    }
    return $dest
}
#endregion

#region ── Main ─────────────────────────────────────────────────────────────────
$engine = if ($PSVersionTable.PSVersion.Major -lt 6) { 'Windows PowerShell' } else { 'PowerShell' }
$engineVer = $PSVersionTable.PSVersion.ToString()
$scriptName = $MyInvocation.MyCommand.Name

Write-LogInfo "===== $scriptName started | v$Script:Version | $engine $engineVer ====="
Write-LogInfo ("Source='{0}' | Dest='{1}' | Extensions=[{2}] | Recurse={3} | ConflictMode={4} | DeleteMode={5}" `
        -f $SourceFolder, $DestinationFolder, ($Extensions -join ','), $Recurse, $ConflictMode, $DeleteMode)

try {
    # Ensure destination folder exists
    if (-not (Test-Path -LiteralPath $DestinationFolder)) {
        if ($PSCmdlet.ShouldProcess($DestinationFolder, 'Create destination folder')) {
            New-Item -ItemType Directory -Path $DestinationFolder -Force | Out-Null
            Write-LogInfo "Created destination folder: '$DestinationFolder'"
        }
    }

    # Enumerate candidate files
    $gciParams = @{
        LiteralPath = $SourceFolder
        File        = $true
        Force       = $true
        ErrorAction = 'Stop'
    }
    if ($Recurse) { $gciParams.Recurse = $true }

    $allFiles = Get-ChildItem @gciParams
    $candidates = $allFiles | Where-Object {
        ($Extensions -contains $_.Extension.ToLowerInvariant()) -and
        (-not ($destIsUnderSource -and
            $_.FullName.StartsWith($resolvedDest + '\', [System.StringComparison]::OrdinalIgnoreCase)))
    }
    $total = ($candidates | Measure-Object).Count

    Write-LogInfo "Found $total file(s) matching extensions: $($Extensions -join ', ')"

    if ($total -eq 0) {
        Write-LogInfo 'No matching files to copy.'
    }
    else {
        foreach ($file in $candidates) {
            $srcPath = $file.FullName
            $fileName = $file.Name
            $destPath = Join-Path $DestinationFolder $fileName

            # Handle conflicts
            if (Test-Path -LiteralPath $destPath) {
                switch ($ConflictMode) {
                    'Rename' {
                        $destPath = Get-UniqueDestPath -Directory $DestinationFolder -FileName $fileName
                        Write-LogInfo ("Conflict: will copy as '$([IO.Path]::GetFileName($destPath))'" )
                    }
                    'Skip' {
                        Write-LogInfo "Skipped (conflict): '$srcPath'"
                        $script:Skipped++
                        continue
                    }
                    'Overwrite' {
                        Write-LogInfo "Conflict: overwriting '$destPath'"
                    }
                }
            }

            # Copy the file
            Write-LogInfo "Copying: '$srcPath' -> '$destPath'"

            if ($PSCmdlet.ShouldProcess($srcPath, "Copy to '$destPath'")) {
                try {
                    Copy-Item -LiteralPath $srcPath -Destination $destPath -Force -ErrorAction Stop

                    if (-not (Test-Path -LiteralPath $destPath)) {
                        Write-LogError "Copy verification failed – '$destPath' not found after copy."
                        $script:Failed++
                        continue
                    }

                    $script:Copied++
                    Write-LogInfo "Copied OK: '$fileName'"

                    # Delete source after successful copy
                    if ($DeleteMode -ne 'None') {
                        try {
                            switch ($DeleteMode) {
                                'Immediate' {
                                    Remove-Item -LiteralPath $srcPath -Force -ErrorAction Stop
                                    if (Test-Path -LiteralPath $srcPath) {
                                        Write-LogError "Delete verification failed (still exists): '$srcPath'"
                                        $script:DelFailed++
                                    }
                                    else {
                                        Write-LogInfo "Deleted source: '$srcPath'"
                                        $script:Deleted++
                                    }
                                }
                                'RecycleBin' {
                                    Remove-ToRecycleBin -FilePath $srcPath
                                    Write-LogInfo "Sent to Recycle Bin: '$srcPath'"
                                    $script:Deleted++
                                }
                            }
                        }
                        catch {
                            Write-LogError ("Failed to delete source '{0}': {1}" -f $srcPath, $_.Exception.Message)
                            $script:DelFailed++
                        }
                    }
                }
                catch {
                    Write-LogError ("Failed to copy '{0}': {1}" -f $srcPath, $_.Exception.Message)
                    $script:Failed++
                }
            }
        }
    }

    # Summary
    Write-LogInfo ("Summary: Total={0}, Copied={1}, Skipped={2}, CopyFailed={3}, Deleted={4}, DeleteFailed={5}" `
            -f $total, $script:Copied, $script:Skipped, $script:Failed, $script:Deleted, $script:DelFailed)
    Write-LogInfo "===== $scriptName ended ====="

    $exitCode = if (($script:Failed -gt 0) -or ($script:DelFailed -gt 0)) { 2 } else { 0 }

    if ($PassThru) {
        [pscustomobject]@{
            Version      = $Script:Version
            Total        = $total
            Copied       = $script:Copied
            Skipped      = $script:Skipped
            CopyFailed   = $script:Failed
            Deleted      = $script:Deleted
            DeleteFailed = $script:DelFailed
            ExitCode     = $exitCode
        }
    }
    else {
        $statusColour = if ($exitCode -eq 0) { 'Green' } elseif ($exitCode -eq 2) { 'Yellow' } else { 'Red' }
        Write-Host ''
        Write-Host '===== Copy-FilesByExtension Summary =====' -ForegroundColor Cyan
        Write-Host ("  Source      : {0}" -f $SourceFolder)
        Write-Host ("  Destination : {0}" -f $DestinationFolder)
        Write-Host ("  Extensions  : {0}" -f ($Extensions -join ', '))
        Write-Host ''
        Write-Host ("  Files found : {0}" -f $total)
        Write-Host ("  Copied      : {0}" -f $script:Copied)
        Write-Host ("  Skipped     : {0}" -f $script:Skipped)
        Write-Host ("  Copy errors : {0}" -f $script:Failed)
        if ($DeleteMode -ne 'None') {
            Write-Host ("  Deleted     : {0}" -f $script:Deleted)
            Write-Host ("  Del errors  : {0}" -f $script:DelFailed)
        }
        Write-Host ''
        Write-Host ("  Status      : {0}" -f $(if ($exitCode -eq 0) { 'Success' } elseif ($exitCode -eq 2) { 'Completed with errors' } else { 'Failed' })) -ForegroundColor $statusColour
        Write-Host '==========================================' -ForegroundColor Cyan
        Write-Host ''
    }

    exit $exitCode
}
catch {
    Write-LogError ("FATAL: {0}" -f $_.Exception.ToString())
    Write-Error $_
    exit 1
}
#endregion
