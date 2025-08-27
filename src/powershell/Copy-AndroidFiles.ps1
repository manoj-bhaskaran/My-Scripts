<#
.SYNOPSIS
    Fast Android → PC transfer via ADB (pull or TAR stream) with progress, optional space checks, resume, and verification.

.VERSION
    1.3.1

.CHANGELOG
    1.3.1
      - Docs: Explicitly note TAR mode is not resumable; recommend pull+Resume for resumption.
      - Logging: Timestamp Write-Warning and retry logs.
      - Verification: Summarize -Verify results in a table (Local vs Remote counts & sizes).
      - Performance: Reduced pull-mode progress polling to 5s (configurable via -ProgressIntervalSeconds).
    1.3.0
      - Added -Verify switch to log post-transfer file counts.
      - Added Get-LocalFileCount and Get-RemoteFileCount helpers.
      - Logged local (and remote estimate) after TAR extraction; mirrored for pull.
    1.2.1
      - Changed -PrecheckSpace to a standard switch (default false).
      - Restored and expanded function-level comment-based help.
    1.2.0
      - Added disk space precheck (-PrecheckSpace, -SpaceMarginPercent).
      - Pull mode resume (-Resume): skip existing files with same size.
      - Tar mode resilience: -MaxRetries, cleanup of partial .tar.
      - Optional streaming tar extraction (-StreamTar) to avoid temp .tar (saves space).
    1.1.0
      - Phone-side tar check, progress for tar, optional progress for pull.
    1.0.0
      - Initial version.

.DESCRIPTION
    Copies files/folders from an Android phone (e.g., Samsung S23) to a Windows PC using ADB.

    Modes:
      - pull : Uses 'adb pull' to mirror the folder. Optional approximate progress; optional -Resume to skip existing files.
               Best option if you need best-effort resumption on interruption.
      - tar  : Uses 'adb exec-out tar' to stream contents as a single archive (to file or directly to extractor),
               then extracts on the PC. This is usually faster for many small files.
               **Important:** TAR mode is **not resumable**. If interrupted, you must re-run the transfer.
               For best-effort resume, use pull mode with -Resume.

.PARAMETER PhonePath
    Android path as seen by ADB (NOT Windows "This PC"). Examples:
      /sdcard/DCIM/Camera
      /sdcard/DCIM/Screenshots
      /sdcard/Download
      /sdcard/Pictures
      /sdcard/WhatsApp/Media/WhatsApp Images
      /sdcard/WhatsApp/Media/WhatsApp Video

    Discover it with:
      adb shell
      ls /sdcard
      ls /sdcard/DCIM
      ls "/sdcard/WhatsApp/Media"

.PARAMETER Dest
    PC destination folder (created if missing).

.PARAMETER Mode
    'pull' or 'tar'.

.PARAMETER ShowProgress
    If set:
      - tar  : shows true size-based progress (bytes).
      - pull : shows approximate progress by polling destination size.

.PARAMETER PrecheckSpace
    If set, validates destination free space before transfer (see also -SpaceMarginPercent).

.PARAMETER SpaceMarginPercent
    Extra headroom for space checks (default 10). Applied to the computed required bytes.

.PARAMETER Resume
    Pull mode only: performs per-file copy and **skips** files already present with identical size.
    Good for resuming interrupted transfers.

.PARAMETER MaxRetries
    Tar mode only: retry count for tar stream when writing to a temporary .tar (default 2).

.PARAMETER StreamTar
    Tar mode only: stream directly to extractor (adb exec-out ... | tar -xf -) to avoid creating a temporary .tar.
    Reduces disk space requirement (no ~2x footprint), but progress is limited.
    **Not resumable** if interrupted.

.PARAMETER Verify
    If set, prints a summary of file counts after transfer:
      - Local count under the copied/extracted root.
      - Best-effort remote count via adb (find|wc -l) for comparison.
    Also prints local/remote sizes in MB (remote size known if computed).

.PARAMETER ProgressIntervalSeconds
    Polling interval (seconds) used when showing progress in pull mode (default 5).
    Higher values reduce I/O overhead on very large trees.

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/DCIM/Camera" -Dest "D:\Phone\Camera" -Mode tar -ShowProgress -PrecheckSpace -StreamTar -Verify

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/Download" -Dest "C:\Phone\Download" -Mode pull -Resume -ShowProgress -Verify

.PREREQUISITES
    1) Enable Developer Options → USB debugging on the phone.
    2) Install Android Platform-Tools; add to PATH; verify:  adb version
    3) Authorize this PC: connect via USB-C (USB 3.x), unlock phone, tap "Allow USB debugging".
       Verify:  adb devices  → shows "<serial>  device"
    4) Windows tar.exe (Win10/11) for Mode 'tar' (or install a compatible tar).
    5) (Optional) Samsung USB driver if Device Manager shows issues.

.TROUBLESHOOTING
    - "unauthorized": toggle USB debugging OFF/ON; revoke USB debug authorizations; replug with a good cable/port.
    - Tar mode fails: ensure phone-side tar available (toybox/busybox). Script checks and fails fast with guidance.
    - Slow transfers: keep phone awake; prefer Mode 'tar' for many small files; ensure SSD destination and free space.

.NOTES
    Works on Windows PowerShell 5.1 and PowerShell 7+.
    Uses approved verb naming (Test-/Confirm-/Get-).
    Author: Manoj Bhaskaran

.LINK
    Android Platform-Tools: https://developer.android.com/studio/releases/platform-tools
#>

[CmdletBinding()]
param(
  [Parameter()] [string]$PhonePath = "/sdcard/Pictures/A_DownloaderForInstagram",
  [Parameter()] [string]$Dest      = "C:\Users\manoj\OneDrive\Desktop\New folder",
  [Parameter()] [ValidateSet('pull','tar')] [string]$Mode = 'tar',
  [Parameter()] [switch]$ShowProgress,
  [Parameter()] [switch]$PrecheckSpace,
  [Parameter()] [int]$SpaceMarginPercent = 10,
  [Parameter()] [switch]$Resume,
  [Parameter()] [int]$MaxRetries = 2,
  [Parameter()] [switch]$StreamTar,
  [Parameter()] [switch]$Verify,
  [Parameter()] [int]$ProgressIntervalSeconds = 5
)

$ErrorActionPreference = 'Stop'

function Test-Adb {
<#
.SYNOPSIS
    Verifies adb.exe is available in PATH.
.DESCRIPTION
    Throws a terminating error if adb.exe is not found.
#>
  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if (-not $adb) { throw "adb.exe not found. Install Platform-Tools and add to PATH." }
}

function Confirm-Device {
<#
.SYNOPSIS
    Confirms an authorized Android device is connected.
.DESCRIPTION
    Runs 'adb devices' and ensures at least one line ends with 'device' status.
    Throws if none are authorized.
#>
  $out = adb devices | Select-String "device`$"
  if (-not $out) {
    throw "No authorized device. Check cable, unlock phone, enable USB debugging, and allow this PC."
  }
}

function Test-HostTar {
<#
.SYNOPSIS
    Verifies tar.exe on Windows when Mode = tar.
.DESCRIPTION
    Ensures 'tar' is available in PATH if TAR mode is selected.
    Throws with guidance if not found.
#>
  if ($Mode -eq 'tar') {
    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
      throw "Windows tar.exe not found. Use -Mode pull or install tar and add to PATH."
    }
  }
}

function Test-PhoneTar {
<#
.SYNOPSIS
    Verifies phone-side tar availability for TAR mode.
.DESCRIPTION
    Checks for 'tar', 'toybox tar', or 'busybox tar' on the device.
    Throws with guidance if none are available.
#>
  if ($Mode -ne 'tar') { return }
  $cmd = 'sh -lc ''(tar --version >/dev/null 2>&1) || (toybox tar --help >/dev/null 2>&1) || (busybox tar --help >/dev/null 2>&1); echo $?'''
  $rc = (adb shell $cmd).Trim()
  if ($rc -ne '0') {
    throw "Phone-side tar not found. Switch to -Mode pull."
  }
}

function Get-RemoteSize {
<#
.SYNOPSIS
    Returns total bytes for a remote (phone) path (best-effort).
.DESCRIPTION
    Attempts multiple strategies on the phone to compute total size:
      - du -sb
      - toybox du -b
      - busybox du -s (×1024)
      - find + stat sum (slowest)
.OUTPUTS
    [Int64] Total size in bytes (0 if unknown/error).
.PARAMETER RemoteParent
    Parent directory of the phone path (POSIX).
.PARAMETER RemoteLeaf
    Leaf (file or directory) name of the phone path.
#>
  param([string]$RemoteParent, [string]$RemoteLeaf)

  $path = "$RemoteParent/$RemoteLeaf"
  $cmd = @"
sh -lc '
(du -sb "$path" 2>/dev/null | awk "{print \$1}") ||
(toybox du -b "$path" 2>/dev/null | awk "{print \$1}") ||
(busybox du -s "$path" 2>/dev/null | awk "{print \$1*1024}") ||
(find "$path" -type f -print0 2>/dev/null | xargs -0 stat -c %s 2>/dev/null | awk "{s+=\$1} END{print s}") ||
echo 0
'
"@
  try {
    $bytes = [int64]((adb shell $cmd).Trim())
    if ($bytes -lt 0) { return 0 } else { return $bytes }
  } catch { return 0 }
}

function Get-LocalDirSize {
<#
.SYNOPSIS
    Returns total bytes for a local directory (best-effort).
.DESCRIPTION
    Recursively sums file lengths under the given path.
.OUTPUTS
    [Int64] Total size in bytes (0 if error/none).
.PARAMETER Path
    Local directory path.
#>
  param([string]$Path)
  try {
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    return ([int64]($sum ? $sum : 0))
  } catch { return 0 }
}

function Get-DriveFreeBytes {
<#
.SYNOPSIS
    Returns free bytes on the drive containing the given local path.
.OUTPUTS
    [Int64] Free bytes.
.PARAMETER Path
    Local path used to locate the drive.
#>
  param([string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $drive = (Get-Item $resolved).PSDrive
  return [int64]$drive.Free
}

function Split-RemotePath {
<#
.SYNOPSIS
    Splits a POSIX path into parent and leaf for use with 'tar -C'.
.OUTPUTS
    [object[]] An array: @($Parent, $Leaf)
.PARAMETER PosixPath
    The remote POSIX-style path (e.g., /sdcard/DCIM/Camera).
#>
  param([string]$PosixPath)
  $parent = ([System.IO.Path]::GetDirectoryName($PosixPath.Replace('/','\'))).Replace('\','/')
  if ([string]::IsNullOrEmpty($parent)) { $parent = "/" }
  $leaf = ([System.IO.Path]::GetFileName($PosixPath))
  return @($parent, $leaf)
}

function Get-LocalFileCount {
<#
.SYNOPSIS
    Returns the number of files under a local path (recursive).
.OUTPUTS
    [Int64] count (0 if none/error).
.PARAMETER Path
    Local directory to scan.
#>
  param([string]$Path)
  try {
    return [int64]((Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                     Measure-Object).Count)
  } catch { return 0 }
}

function Get-RemoteFileCount {
<#
.SYNOPSIS
    Best-effort count of remote (phone) files for a given path.
.DESCRIPTION
    Uses find | wc -l via sh/toybox/busybox. Returns 0 if unavailable.
.OUTPUTS
    [Int64] count (0 if unknown).
.PARAMETER RemoteParent
    Parent directory on the device.
.PARAMETER RemoteLeaf
    Leaf (file or directory) name on the device.
#>
  param([string]$RemoteParent, [string]$RemoteLeaf)
  $path = "$RemoteParent/$RemoteLeaf"
  $cmd = @"
sh -lc '
( find "$path" -type f 2>/dev/null | wc -l ) ||
( toybox find "$path" -type f 2>/dev/null | wc -l ) ||
( busybox find "$path" -type f 2>/dev/null | wc -l ) ||
echo 0
'
"@
  try {
    return [int64]((adb shell $cmd).Trim())
  } catch { return 0 }
}

Write-Verbose "Destination: $Dest"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Pre-checks
Test-Adb
Confirm-Device
Test-HostTar
Test-PhoneTar

# Common path split & remote size (for progress and optional space checks)
$parent, $leaf = Split-RemotePath -PosixPath $PhonePath
$totalBytes = Get-RemoteSize -RemoteParent $parent -RemoteLeaf $leaf

# Optional disk space precheck
if ($PrecheckSpace.IsPresent -and $totalBytes -gt 0) {
  $freeBytes = Get-DriveFreeBytes -Path $Dest
  $needed = if ($Mode -eq 'tar' -and -not $StreamTar) { $totalBytes * 2 } else { $totalBytes }
  $needed = [int64]([math]::Ceiling($needed * (1 + ($SpaceMarginPercent / 100.0))))
  if ($freeBytes -lt $needed) {
    throw ("Insufficient disk space. Need ~{0} MB (incl. margin), have ~{1} MB. " +
           "Tip: enable -StreamTar to avoid temp .tar, or free up space.")
           -f ([math]::Round($needed/1MB)), ([math]::Round($freeBytes/1MB))
  }
}

if ($Mode -eq 'pull') {

  if ($Resume) {
    Write-Host "Resumable pull (skip existing): `"$PhonePath`" → `"$Dest`""
    # Build remote file list (size \t path)
    $listCmd = "sh -lc 'find ""$PhonePath"" -type f -print0 2>/dev/null | xargs -0 stat -c ""%s`t%n"" 2>/dev/null'"
    $raw = adb shell $listCmd
    $lines = @()
    if ($raw) { $lines = $raw -split "`r?`n" }

    $count = 0; $copied = 0
    foreach ($line in $lines) {
      if (-not $line) { continue }
      $parts = $line -split "`t", 2
      if ($parts.Count -lt 2) { continue }
      $sz  = [int64]$parts[0]
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
    Write-Host "Resume pull complete. Files processed: $count, newly copied: $copied."

    if ($Verify) {
      $localCount  = Get-LocalFileCount -Path $Dest
      $remoteCount = Get-RemoteFileCount -RemoteParent $parent -RemoteLeaf $leaf
      $localSizeMB  = [math]::Round((Get-LocalDirSize -Path $Dest)/1MB)
      $remoteSizeMB = if ($totalBytes -gt 0) { [math]::Round($totalBytes/1MB) } else { $null }
      $rows = @(
        [pscustomobject]@{ Scope='Local';  Files=$localCount;  SizeMB=$localSizeMB  }
        [pscustomobject]@{ Scope='Remote'; Files=$remoteCount; SizeMB=$remoteSizeMB }
      )
      $rows | Format-Table -AutoSize | Out-String | Write-Host
      if ($remoteCount -gt 0 -and $localCount -lt $remoteCount) {
        Write-Warning "Local file count < remote file count. Some files may be missing."
      }
    }
  }
  else {
    Write-Host "ADB pull `"$PhonePath`" → `"$Dest`""
    if ($ShowProgress) {
      $destBefore = Get-LocalDirSize -Path $Dest
      $proc = Start-Process adb -ArgumentList @('pull',"$PhonePath","$Dest") -NoNewWindow -PassThru
      while (-not $proc.HasExited) {
        Start-Sleep -Seconds $ProgressIntervalSeconds
        $cur = Get-LocalDirSize -Path $Dest
        $written = [math]::Max(0, $cur - $destBefore)
        if ($totalBytes -gt 0) {
          $pct = [int](($written * 100.0) / $totalBytes)
          Write-Progress -Activity "adb pull" -Status "$pct% ($([math]::Round($written/1MB)) / $([math]::Round($totalBytes/1MB)) MB)" -PercentComplete $pct
        } else {
          Write-Progress -Activity "adb pull" -Status "$([math]::Round($written/1MB)) MB copied (approx)" -PercentComplete 0
        }
      }
      Write-Progress -Activity "adb pull" -Completed
      if ($proc.ExitCode -ne 0) { throw "adb pull failed with exit code $($proc.ExitCode)." }
    } else {
      adb pull "$PhonePath" "$Dest"
    }
    Write-Host "Pull complete."

    if ($Verify) {
      # In bulk pull, adb creates a subfolder under Dest with the leaf name
      $verifyRoot  = Join-Path $Dest $leaf
      $rootToCount = (Test-Path $verifyRoot) ? $verifyRoot : $Dest
      $localCount  = Get-LocalFileCount -Path $rootToCount
      $remoteCount = Get-RemoteFileCount -RemoteParent $parent -RemoteLeaf $leaf
      $localSizeMB  = [math]::Round((Get-LocalDirSize -Path $rootToCount)/1MB)
      $remoteSizeMB = if ($totalBytes -gt 0) { [math]::Round($totalBytes/1MB) } else { $null }
      $rows = @(
        [pscustomobject]@{ Scope='Local';  Files=$localCount;  SizeMB=$localSizeMB  }
        [pscustomobject]@{ Scope='Remote'; Files=$remoteCount; SizeMB=$remoteSizeMB }
      )
      $rows | Format-Table -AutoSize | Out-String | Write-Host
      if ($remoteCount -gt 0 -and $localCount -lt $remoteCount) {
        Write-Warning "Local file count < remote file count. Some files may be missing."
      }
    }
  }

}
else {
  # TAR mode
  if ($StreamTar) {
    Write-Host "Streaming TAR directly to extractor (no temp .tar): `"$PhonePath`" → `"$Dest`""
    if ($ShowProgress -and $totalBytes -gt 0) {
      Write-Host ("Estimated size: {0} MB" -f [math]::Round($totalBytes/1MB))
    }
    # Use cmd.exe pipeline for robust stdin handling to tar.exe across shells
    $cmd = "adb exec-out tar -C '$parent' -cf - '$leaf' | tar -xf - -C '$Dest'"
    cmd /c $cmd | Out-Host
    Write-Host "Streaming tar extraction finished. Verify contents."

    if ($Verify) {
      $localCount  = Get-LocalFileCount -Path $Dest
      $remoteCount = Get-RemoteFileCount -RemoteParent $parent -RemoteLeaf $leaf
      $localSizeMB  = [math]::Round((Get-LocalDirSize -Path $Dest)/1MB)
      $remoteSizeMB = if ($totalBytes -gt 0) { [math]::Round($totalBytes/1MB) } else { $null }
      $rows = @(
        [pscustomobject]@{ Scope='Local';  Files=$localCount;  SizeMB=$localSizeMB  }
        [pscustomobject]@{ Scope='Remote'; Files=$remoteCount; SizeMB=$remoteSizeMB }
      )
      $rows | Format-Table -AutoSize | Out-String | Write-Host
      if ($remoteCount -gt 0 -and $localCount -lt $remoteCount) {
        Write-Warning "Extracted count < remote count. Some files may be missing."
      }
    }
  }
  else {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $tarFile   = Join-Path $Dest ("android_{0}.tar" -f $timestamp)

    $attempt = 0
    while ($true) {
      try {
        $attempt++
        Write-Host "Attempt $attempt of $MaxRetries — streaming TAR from `"$PhonePath`" → `"$tarFile`""
        $proc = Start-Process adb -ArgumentList @('exec-out','tar','-C',"$parent",'-cf','-',$leaf) `
                 -RedirectStandardOutput $tarFile -NoNewWindow -PassThru

        if ($ShowProgress) {
          while (-not $proc.HasExited) {
            Start-Sleep -Seconds 1
            $cur = (Test-Path $tarFile) ? ((Get-Item $tarFile).Length) : 0
            if ($totalBytes -gt 0) {
              $pct = [int](($cur * 100.0) / $totalBytes)
              Write-Progress -Activity "Streaming TAR" -Status "$pct% ($([math]::Round($cur/1MB)) / $([math]::Round($totalBytes/1MB)) MB)" -PercentComplete $pct
            } else {
              Write-Progress -Activity "Streaming TAR" -Status "$([math]::Round($cur/1MB)) MB written" -PercentComplete 0
            }
          }
          Write-Progress -Activity "Streaming TAR" -Completed
        } else {
          $proc.WaitForExit()
        }

        if ($proc.ExitCode -ne 0) { throw "adb tar stream failed with exit code $($proc.ExitCode)." }

        $finalSize = (Get-Item $tarFile).Length
        Write-Host ("TAR complete. Size: {0:N0} bytes ({1} MB)" -f $finalSize, [math]::Round($finalSize/1MB))

        Write-Host "Extracting `"$tarFile`" → `"$Dest`""
        tar -xf $tarFile -C $Dest

        if ($Verify) {
          $localCount  = Get-LocalFileCount -Path $Dest
          $remoteCount = Get-RemoteFileCount -RemoteParent $parent -RemoteLeaf $leaf
          $localSizeMB  = [math]::Round((Get-LocalDirSize -Path $Dest)/1MB)
          $remoteSizeMB = if ($totalBytes -gt 0) { [math]::Round($totalBytes/1MB) } else { $null }
          $rows = @(
            [pscustomobject]@{ Scope='Local';  Files=$localCount;  SizeMB=$localSizeMB  }
            [pscustomobject]@{ Scope='Remote'; Files=$remoteCount; SizeMB=$remoteSizeMB }
          )
          $rows | Format-Table -AutoSize | Out-String | Write-Host
          if ($remoteCount -gt 0 -and $localCount -lt $remoteCount) {
            Write-Warning "Extracted count < remote count. Some files may be missing."
          }
        }

        # Cleanup
        Remove-Item $tarFile -Force
        Write-Host "Done."
        break
      }
      catch {
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Warning ("{0}: {1}" -f $ts, $_)
        if (Test-Path $tarFile) { Remove-Item $tarFile -Force -ErrorAction SilentlyContinue }
        if ($attempt -ge $MaxRetries) { throw "Tar mode failed after $MaxRetries attempts." }
        Start-Sleep 2
        Write-Host    ("{0}: Retrying..." -f $ts)
      }
    }
  }
}
