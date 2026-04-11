<#
.SYNOPSIS
    Fast Android → PC transfer via ADB (pull or TAR stream) with progress, optional space checks,
    resume, verification, and optional debug logging.

.DESCRIPTION
    Copies files/folders from an Android phone (e.g., Samsung S23) to a Windows PC using ADB.

    Modes (selected via parameter set):
      - Pull (parameter set 'Pull'): Uses 'adb pull' to mirror the folder. Optional approximate
               progress; optional -Resume to skip existing files. Best option if you need
               best-effort resumption on interruption. Activated by passing -Resume or
               -ProgressIntervalSeconds.
      - Tar  (parameter set 'Tar', default): Uses 'adb exec-out tar' to stream contents as a
               single archive (to file or directly to extractor), then extracts on the PC.
               This is usually faster for many small files. Activated by passing -StreamTar or
               -MaxRetries, or when no mode-specific parameters are specified.
               **Important:** TAR mode is **not resumable**. If interrupted, re-run the transfer.
               For best-effort resume, use pull mode with -Resume.

    Optional Debugging:
      - Use -DebugMode to log the exact adb shell command lines (via Invoke-AdbSh) and capture adb
        stderr during long transfers. Safe for TAR streams (stdout is never logged in TAR mode) and
        low-noise for pull mode.

    With -Verify, the summary now includes Local before → after (+Δ) for both file counts and sizes.

.PARAMETER PhonePath
    Android path as seen by ADB (NOT Windows "This PC"). Examples:
      /sdcard/DCIM/Camera
      /sdcard/DCIM/Screenshots
      /sdcard/Download
      /sdcard/Pictures
      /sdcard/WhatsApp/Media/WhatsApp Images
      /sdcard/WhatsApp/Media/WhatsApp Video

.PARAMETER Dest
    PC destination folder (created if missing).

.PARAMETER Mode
    Determines the transfer mode. This parameter has been retired; the mode is now selected
    implicitly by the parameter set:
      - Use pull-mode parameters (-Resume, -ProgressIntervalSeconds) to activate pull mode.
      - Use tar-mode parameters (-StreamTar, -MaxRetries) to activate tar mode.
      - When no mode-specific parameters are provided, tar mode is used by default.

.PARAMETER ShowProgress
    If set:
      - tar  : shows true size-based progress (bytes).
      - pull : shows approximate progress by polling destination size.

.PARAMETER PrecheckSpace
    If set, validates destination free space before transfer (see also -SpaceMarginPercent).

.PARAMETER SpaceMarginPercent
    Extra headroom for space checks (default 10). Applied to the computed required bytes.

.PARAMETER Resume
    Pull mode only: per-file copy and **skip** existing files with identical size.
    Selecting this parameter activates pull mode (parameter set 'Pull').

.PARAMETER MaxRetries
    Tar-to-file mode: retry count for tar stream (default 2).
    Only valid in tar mode (parameter set 'Tar').

.PARAMETER StreamTar
    Tar mode: stream directly to extractor (adb exec-out ... | tar -xf -) to avoid creating
    a temporary .tar. Reduces disk space requirement (no ~2x footprint). **Not resumable**
    if interrupted.
    Selecting this parameter activates tar mode (parameter set 'Tar').

.PARAMETER Verify
    If set, prints a summary table of file counts/sizes after transfer:
      - Local: shows “before → after (+Δ)” for Files and SizeMB
      - Remote: best-effort counts/sizes (via ADB), when available
    Notes:
      - Baseline (“before”) is captured once at start and depends on mode:
          * pull (default): baseline = $Dest\$leaf if adb creates that subfolder; else $Dest
          * pull -Resume and tar modes (stream/file): baseline = $Dest

.PARAMETER ProgressIntervalSeconds
    Polling interval (seconds) for pull mode progress (default 5). Higher values reduce I/O overhead.
    Only valid in pull mode (parameter set 'Pull').

.PARAMETER DebugMode
    Enables lightweight diagnostics for adb interactions:
      - Logs the single-line shell sent to the device (via Invoke-AdbSh), including a small prefix
        of stdout and its total length.
      - Captures adb stderr for TAR-to-file mode, and both stdout/stderr for pull mode.
      - Creates a timestamped log file under the destination folder (e.g., adb_debug_YYYYMMDD_HHMMSS.log)
    Notes:
      - No ADB_TRACE is enabled by default to avoid performance and privacy issues.
      - Logs may include device serials and paths—review before sharing.

.INPUTS
    None. You cannot pipe input to this script.

.OUTPUTS
    None. Writes status/progress to the console. When -Verify is used, writes a summary table.

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/DCIM/Camera" -Dest "D:\Phone\Camera" `
      -ShowProgress -PrecheckSpace -StreamTar -Verify

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/Download" -Dest "C:\Phone\Download" `
      -Resume -ShowProgress -Verify

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/DCIM/Camera" -Dest "D:\Phone\Camera" -Resume -Verify

    # Example Verify output (values illustrative):
    Scope  Files                          SizeMB
    -----  -----------------------------  --------------------------
    Local  12,345 → 29,100 (+16,755)     1,233 → 7,379 (+6,146)
    Remote 12,502                         1,833

.LINK
    Android Platform-Tools: https://developer.android.com/studio/releases/platform-tools

.NOTES
    Version: 2.3.2
    See CHANGELOG.md in this directory for full version history.

    PREREQUISITES
      1) Enable Developer Options on the phone
           Settings → About phone → Software information → tap "Build number" 7 times.
           Then open: Settings → Developer options.
      2) Enable USB debugging
           Settings → Developer options → USB debugging = ON.
      3) Install Android Platform-Tools (ADB) on Windows
           - Download the official "SDK Platform-Tools for Windows" ZIP from Google.
           - Extract to a fixed path (e.g., C:\platform-tools).
           - Add that folder to PATH.
           - Verify in PowerShell:
               adb version
      4) Authorize this PC on the phone
           - Connect via a good USB-C cable (prefer USB 3.x) and an SS/USB-3 port.
           - Unlock the phone screen.
           - When prompted “Allow USB debugging?”, tick "Always allow" and tap Allow.
           - Verify:
               adb devices
             Expected: <serial>    device
      5) Windows tar (for tar mode)
           - Windows 10/11 include tar.exe.
           - If missing, install a compatible tar or use pull mode (pass -Resume).
      6) Optional drivers
           - If Device Manager shows issues, install the Samsung USB driver (or OEM driver).
      7) Storage & space
           - Ensure the destination drive has enough free space (use -PrecheckSpace for validation).
           - For tar-to-file mode, you may need up to ~2× the source size (archive + extracted)
             unless using -StreamTar.
      8) (Optional) Debug logs
           - With -DebugMode, a timestamped log is written under the destination folder.
           - Logs may include device serials and paths; review before sharing.

    TROUBLESHOOTING
      - Ensure adb.exe is installed and in PATH (install Android SDK Platform-Tools).
      - Ensure the phone is connected, unlocked, and USB debugging is enabled/authorized.
      - If tar mode fails due to missing phone-side tar, switch to pull mode or install tar on the device.
        To use pull mode, pass -Resume or -ProgressIntervalSeconds (pull-only parameters).
      - If adb pull is very slow, try tar mode (omit pull-only parameters, or pass -StreamTar).
      - If interrupted during tar mode, re-run the transfer (not resumable). For resumable transfers, use pull mode with -Resume.
      - Use -DebugMode to log adb interactions for troubleshooting.
          * TAR mode: only stderr is logged (stdout is the binary .tar).
          * Pull mode: both stdout and stderr are logged.
      - /system/bin/sh parsing errors (e.g., “unexpected ';'”):
          * Ensure you are on ≥ 1.3.5. The script uses Invoke-AdbSh to normalize line endings and flatten scripts.
#>

[CmdletBinding(DefaultParameterSetName = 'Tar')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Pull')]
    [Parameter(Mandatory, ParameterSetName = 'Tar')]
    [string]$PhonePath,

    [Parameter(Mandatory, ParameterSetName = 'Pull')]
    [Parameter(Mandatory, ParameterSetName = 'Tar')]
    [string]$Dest,

    [Parameter(ParameterSetName = 'Pull')] [switch]$Resume,
    [Parameter(ParameterSetName = 'Pull')] [int]$ProgressIntervalSeconds = 5,

    [Parameter(ParameterSetName = 'Tar')]  [switch]$StreamTar,
    [Parameter(ParameterSetName = 'Tar')]  [int]$MaxRetries = 2,

    [Parameter()] [switch]$ShowProgress,
    [Parameter()] [switch]$PrecheckSpace,
    [Parameter()] [int]$SpaceMarginPercent = 10,
    [Parameter()] [switch]$Verify,
    [Parameter()] [switch]$DebugMode
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Android\AdbHelpers\AdbHelpers.psd1" -Force

# Initialize logger (script name will be extracted from the script file name)
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

$ErrorActionPreference = 'Stop'

$DebugLog = $null
if ($DebugMode) {
    $DebugLog = Join-Path ($Dest) ("adb_debug_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    Write-Host "Debug mode: logging to $DebugLog"
}

function Get-LocalDirSize {
    <#
.SYNOPSIS
    Returns total bytes for a local directory (best-effort).
.DESCRIPTION
    Recursively sums file lengths under the given path; ignores inaccessible files.
.PARAMETER Path
    Local directory to scan.
.OUTPUTS
    [Int64] total size in bytes (0 if error/none).
#>
    param([string]$Path)
    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        [int64]($sum ? $sum : 0)
    } catch { 0 }
}

function Get-DriveFreeBytes {
    <#
.SYNOPSIS
    Returns free bytes on the drive containing the given local path.
.DESCRIPTION
    Resolves the path to its PSDrive and returns the Free property.
.PARAMETER Path
    Any local path on the target drive.
.OUTPUTS
    [Int64] free bytes.
#>
    param([string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $drive = (Get-Item $resolved).PSDrive
    [int64]$drive.Free
}

function Split-RemotePath {
    <#
.SYNOPSIS
    Splits a POSIX path into parent and leaf (for tar -C usage).
.DESCRIPTION
    Converts to Windows-style temporarily to use .NET Path helpers, then normalizes back to POSIX.
.PARAMETER PosixPath
    Remote POSIX path (e.g., /sdcard/DCIM/Camera).
.OUTPUTS
    [object[]] array: @($Parent, $Leaf)
#>
    param([string]$PosixPath)
    $parent = ([System.IO.Path]::GetDirectoryName($PosixPath.Replace('/', '\'))).Replace('\', '/')
    if ([string]::IsNullOrEmpty($parent)) { $parent = "/" }
    $leaf = ([System.IO.Path]::GetFileName($PosixPath))
    @($parent, $leaf)
}

function Get-LocalFileCount {
    <#
.SYNOPSIS
    Returns the number of files under a local path (recursive).
.DESCRIPTION
    Counts regular files; suppresses access errors.
.PARAMETER Path
    Local directory to scan.
.OUTPUTS
    [Int64] count (0 if none/error).
#>
    param([string]$Path)
    try {
        [int64]((Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                Measure-Object).Count)
    } catch { 0 }
}

function Write-VerifySummary {
    <#
.SYNOPSIS
    Prints a post-transfer verification summary table and warns if local count is below remote.
.DESCRIPTION
    Calculates post-transfer local file counts and sizes, retrieves remote file counts,
    displays comparative statistics in table format, and emits a properly-logged warning
    when the local count falls below the remote count.
.PARAMETER LocalRoot
    Local directory to measure after transfer.
.PARAMETER FilesBefore
    Local file count captured before transfer.
.PARAMETER BytesBefore
    Local byte total captured before transfer.
.PARAMETER RemoteParent
    Parent directory on the device (POSIX).
.PARAMETER RemoteLeaf
    Leaf (file or directory) name on the device.
.PARAMETER TotalBytes
    Pre-transfer remote size in bytes (used to derive SizeMB for Remote row).
.PARAMETER WarnMessage
    Warning text emitted via Write-LogWarning if local count < remote count.
.OUTPUTS
    None. Writes a formatted table to the host and optionally a warning to the log.
#>
    param(
        [string]$LocalRoot,
        [int64]$FilesBefore,
        [int64]$BytesBefore,
        [string]$RemoteParent,
        [string]$RemoteLeaf,
        [int64]$TotalBytes,
        [string]$WarnMessage,
        [switch]$DebugMode,
        [string]$DebugLog
    )

    $localCount = Get-LocalFileCount  -Path $LocalRoot
    $localBytes = Get-LocalDirSize    -Path $LocalRoot
    $remoteCount = Get-RemoteFileCount -RemoteParent $RemoteParent -RemoteLeaf $RemoteLeaf -DebugMode:$DebugMode -DebugLog $DebugLog
    $remoteSizeMB = if ($TotalBytes -gt 0) { [math]::Round($TotalBytes / 1MB) } else { $null }

    $afterFiles = $localCount
    $deltaFiles = $afterFiles - $FilesBefore

    $beforeMB = [math]::Round($BytesBefore / 1MB)
    $afterMB = [math]::Round($localBytes / 1MB)
    $deltaMB = $afterMB - $beforeMB

    $rows = @(
        [pscustomobject]@{
            Scope  = 'Local'
            Files  = ("{0} → {1} (+{2})" -f $FilesBefore, $afterFiles, $deltaFiles)
            SizeMB = ("{0} → {1} (+{2})" -f $beforeMB, $afterMB, $deltaMB)
        }
        [pscustomobject]@{
            Scope  = 'Remote'
            Files  = $remoteCount
            SizeMB = $remoteSizeMB
        }
    )
    $rows | Format-Table -AutoSize | Out-String | Write-Host

    if ($remoteCount -gt 0 -and $localCount -lt $remoteCount) {
        Write-LogWarning $WarnMessage
    }
}

function Invoke-ProgressWhileProcess {
    <#
.SYNOPSIS
    Polls a running process and writes a progress bar until the process exits.
.DESCRIPTION
    Loops while the process has not exited, invoking $GetCurrentBytes on each iteration to
    obtain an up-to-date byte count. When $TotalBytes is known (> 0), shows a percentage bar;
    otherwise shows MB written only. Calls Write-Progress -Completed before returning.
.PARAMETER Process
    The System.Diagnostics.Process object to monitor.
.PARAMETER Activity
    Activity label passed to Write-Progress.
.PARAMETER GetCurrentBytes
    Scriptblock that returns the current byte count ([Int64]) relevant to this transfer.
.PARAMETER TotalBytes
    Expected total bytes. When > 0, enables percentage display.
.PARAMETER IntervalSeconds
    Polling interval in seconds (default 1).
.OUTPUTS
    None. Writes progress to the console via Write-Progress.
#>
    param(
        [System.Diagnostics.Process]$Process,
        [string]$Activity,
        [scriptblock]$GetCurrentBytes,
        [int64]$TotalBytes,
        [int]$IntervalSeconds = 1
    )
    while (-not $Process.HasExited) {
        Start-Sleep -Seconds $IntervalSeconds
        $cur = & $GetCurrentBytes
        if ($TotalBytes -gt 0) {
            $pct = [int](($cur * 100.0) / $TotalBytes)
            Write-Progress -Activity $Activity -Status "$pct% ($([math]::Round($cur/1MB)) / $([math]::Round($TotalBytes/1MB)) MB)" -PercentComplete $pct
        } else {
            Write-Progress -Activity $Activity -Status "$([math]::Round($cur/1MB)) MB written" -PercentComplete 0
        }
    }
    Write-Progress -Activity $Activity -Completed
}

Write-LogDebug "Destination: $Dest"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Pre-checks
Test-Adb
Confirm-Device
Test-HostTar -Mode $PSCmdlet.ParameterSetName
Test-PhoneTar -Mode $PSCmdlet.ParameterSetName -DebugMode:$DebugMode -DebugLog $DebugLog

# Common path split & remote size (for progress/space checks)
$parent, $leaf = Split-RemotePath -PosixPath $PhonePath
$totalBytes = Get-RemoteSize -RemoteParent $parent -RemoteLeaf $leaf -DebugMode:$DebugMode -DebugLog $DebugLog

# Baseline local stats for Verify deltas
# For non-resume pull, adb creates a subfolder ($leaf) under $Dest → baseline that path.
# For resume pull and tar modes, we write directly under $Dest → baseline $Dest.
$localRootBaseline = if ($PSCmdlet.ParameterSetName -eq 'Pull' -and -not $Resume) { Join-Path $Dest $leaf } else { $Dest }
$LocalFilesBefore = Get-LocalFileCount -Path $localRootBaseline
$LocalBytesBefore = Get-LocalDirSize  -Path $localRootBaseline

# Optional disk space precheck
if ($PrecheckSpace.IsPresent -and $totalBytes -gt 0) {
    $freeBytes = Get-DriveFreeBytes -Path $Dest
    $needed = if ($PSCmdlet.ParameterSetName -eq 'Tar' -and -not $StreamTar) { $totalBytes * 2 } else { $totalBytes }
    $needed = [int64]([math]::Ceiling($needed * (1 + ($SpaceMarginPercent / 100.0))))
    if ($freeBytes -lt $needed) {
        throw ("Insufficient disk space. Need ~{0} MB (incl. margin), have ~{1} MB. " +
            "Tip: enable -StreamTar to avoid temp .tar, or free up space.")
        -f ([math]::Round($needed / 1MB)), ([math]::Round($freeBytes / 1MB))
    }
}

if ($PSCmdlet.ParameterSetName -eq 'Pull') {

    if ($Resume) {
        Write-LogInfo "Resumable pull (skip existing): `"$PhonePath`" → `"$Dest`""
        # Build remote file list (size \t path)
        $listCmd = "find ""$PhonePath"" -type f -print0 2>/dev/null | xargs -0 stat -c ""%s`t%n"" 2>/dev/null"
        $raw = adb shell $listCmd
        $lines = @()
        if ($raw) { $lines = $raw -split "\r?\n" }

        $count = 0; $copied = 0
        foreach ($line in $lines) {
            if (-not $line) { continue }
            $parts = $line -split "`t", 2
            if ($parts.Count -lt 2) { continue }
            $sz = [int64]$parts[0]
            $src = $parts[1]

            $rel = $src.Substring($PhonePath.Length).TrimStart('/')
            $dst = Join-Path $Dest ($rel -replace '/', '\')
            $dstDir = Split-Path $dst -Parent
            New-Item -ItemType Directory -Force -Path $dstDir | Out-Null

            $count++
            $skip = (Test-Path -LiteralPath $dst) -and ((Get-Item -LiteralPath $dst).Length -eq $sz)
            if ($skip) { continue }

            if ($ShowProgress -and $totalBytes -gt 0) {
                $doneBytes = Get-LocalDirSize -Path $Dest
                $pct = [int](($doneBytes * 100.0) / $totalBytes)
                Write-Progress -Activity "Resumable adb pull" -Status "File $count (≈$pct%)" -PercentComplete $pct
            }

            adb pull "$src" "$dstDir" | Out-Null
            $copied++
        }
        Write-Progress -Activity "Resumable adb pull" -Completed
        Write-LogInfo "Resume pull complete. Files processed: $count, newly copied: $copied."

        if ($Verify) {
            Write-VerifySummary -LocalRoot $Dest `
                -FilesBefore $LocalFilesBefore -BytesBefore $LocalBytesBefore `
                -RemoteParent $parent -RemoteLeaf $leaf -TotalBytes $totalBytes `
                -WarnMessage "Local file count < remote file count. Some files may be missing." `
                -DebugMode:$DebugMode -DebugLog $DebugLog
        }
    } else {
        Write-LogInfo "ADB pull `"$PhonePath`" → `"$Dest`""
        if ($ShowProgress) {
            $destBefore = Get-LocalDirSize -Path $Dest
            $sp = @{
                FilePath     = 'adb'
                ArgumentList = @('pull', "$PhonePath", "$Dest")
                NoNewWindow  = $true
                PassThru     = $true
            }
            if ($DebugMode -and $DebugLog) {
                $sp.RedirectStandardError = $DebugLog
                $sp.RedirectStandardOutput = $DebugLog
            }
            $proc = Start-Process @sp
            Invoke-ProgressWhileProcess -Process $proc -Activity "adb pull" `
                -GetCurrentBytes { [math]::Max(0, (Get-LocalDirSize $Dest) - $destBefore) } `
                -TotalBytes $totalBytes -IntervalSeconds $ProgressIntervalSeconds
            if ($proc.ExitCode -ne 0) { throw "adb pull failed with exit code $($proc.ExitCode)." }
        } else {
            adb pull "$PhonePath" "$Dest"
        }
        Write-LogInfo "Pull complete."

        if ($Verify) {
            # adb pull usually creates a subfolder under Dest named $leaf
            $verifyRoot = Join-Path $Dest $leaf
            $localRootAfter = (Test-Path $verifyRoot) ? $verifyRoot : $Dest
            Write-VerifySummary -LocalRoot $localRootAfter `
                -FilesBefore $LocalFilesBefore -BytesBefore $LocalBytesBefore `
                -RemoteParent $parent -RemoteLeaf $leaf -TotalBytes $totalBytes `
                -WarnMessage "Local file count < remote file count. Some files may be missing." `
                -DebugMode:$DebugMode -DebugLog $DebugLog
        }
    }
} else {
    # TAR mode
    if ($StreamTar) {
        Write-LogInfo "Streaming TAR directly to extractor (no temp .tar): `"$PhonePath`" → `"$Dest`""
        if ($ShowProgress -and $totalBytes -gt 0) {
            Write-LogInfo ("Estimated size: {0} MB" -f [math]::Round($totalBytes / 1MB))
        }
        # Use cmd.exe pipeline for robust stdin handling to tar.exe across shells
        $cmd = "adb exec-out tar -C '$parent' -cf - '$leaf' | tar -xf - -C '$Dest'"
        cmd /c $cmd | Out-Host
        Write-LogInfo "Streaming tar extraction finished. Verify contents."

        if ($Verify) {
            Write-VerifySummary -LocalRoot $Dest `
                -FilesBefore $LocalFilesBefore -BytesBefore $LocalBytesBefore `
                -RemoteParent $parent -RemoteLeaf $leaf -TotalBytes $totalBytes `
                -WarnMessage "Extracted count < remote count. Some files may be missing." `
                -DebugMode:$DebugMode -DebugLog $DebugLog
        }
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $tarFile = Join-Path $Dest ("android_{0}.tar" -f $timestamp)

        $attempt = 0
        while ($true) {
            try {
                $attempt++
                Write-LogInfo "Attempt $attempt of $MaxRetries — streaming TAR from `"$PhonePath`" → `"$tarFile`""
                $sp = @{
                    FilePath               = 'adb'
                    ArgumentList           = @('exec-out', 'tar', '-C', "$parent", '-cf', '-', $leaf)
                    RedirectStandardOutput = $tarFile
                    NoNewWindow            = $true
                    PassThru               = $true
                }
                if ($DebugMode -and $DebugLog) {
                    $sp.RedirectStandardError = $DebugLog
                }
                $proc = Start-Process @sp

                if ($ShowProgress) {
                    Invoke-ProgressWhileProcess -Process $proc -Activity "Streaming TAR" `
                        -GetCurrentBytes { if (Test-Path $tarFile) { (Get-Item $tarFile).Length } else { 0 } } `
                        -TotalBytes $totalBytes -IntervalSeconds 1
                } else {
                    $proc.WaitForExit()
                }

                if ($proc.ExitCode -ne 0) { throw "adb tar stream failed with exit code $($proc.ExitCode)." }

                $finalSize = (Get-Item $tarFile).Length
                Write-LogInfo ("TAR complete. Size: {0:N0} bytes ({1} MB)" -f $finalSize, [math]::Round($finalSize / 1MB))

                Write-LogInfo "Extracting `"$tarFile`" → `"$Dest`""
                tar -xf $tarFile -C $Dest

                if ($Verify) {
                    Write-VerifySummary -LocalRoot $Dest `
                        -FilesBefore $LocalFilesBefore -BytesBefore $LocalBytesBefore `
                        -RemoteParent $parent -RemoteLeaf $leaf -TotalBytes $totalBytes `
                        -WarnMessage "Extracted count < remote count. Some files may be missing." `
                        -DebugMode:$DebugMode -DebugLog $DebugLog
                }

                # Cleanup
                Remove-Item $tarFile -Force
                Write-LogInfo "Done."
                break
            } catch {
                $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Write-LogWarning ("{0}: {1}" -f $ts, $_)
                if (Test-Path $tarFile) { Remove-Item $tarFile -Force -ErrorAction SilentlyContinue }
                if ($attempt -ge $MaxRetries) { throw "Tar mode failed after $MaxRetries attempts." }
                Start-Sleep 2
                Write-LogInfo ("{0}: Retrying..." -f $ts)
            }
        }
    }
}
