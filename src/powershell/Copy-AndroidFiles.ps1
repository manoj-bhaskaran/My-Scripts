<#
.SYNOPSIS
    Fast Android → PC transfer via ADB (pull or TAR stream) with progress, optional space checks, resume, and verification.

.VERSION
    1.3.3

.CHANGELOG
    1.3.3
      - Reworked adb shell invocations: removed 'sh -lc' and $0 arg trick.
      - Inline remote path via placeholder replacement to avoid quoting issues.
      - Restored full comment-based help for all functions.
      - Retained awk-free remote size logic (du/stat/find + shell arithmetic).
    1.3.2
      - Removed awk usage from Get-RemoteSize; POSIX shell arithmetic with du/stat/find.
      - Hardened quoting; timestamped warnings; inlined remote path arg for analyzer.
    1.3.1
      - TAR mode explicitly documented as non-resumable; timestamped logs; -Verify table; 5s pull polling.
    1.3.0
      - Added -Verify; file count helpers; verify logs for tar/pull.
    1.2.x
      - Space precheck, resumable pull, TAR retries/cleanup, -StreamTar, etc.

.DESCRIPTION
    Copies files/folders from an Android phone (e.g., Samsung S23) to a Windows PC using ADB.

    Modes:
      - pull : Uses 'adb pull' to mirror the folder. Optional approximate progress; optional -Resume to skip existing files.
               Best option if you need best-effort resumption on interruption.
      - tar  : Uses 'adb exec-out tar' to stream contents as a single archive (to file or directly to extractor),
               then extracts on the PC. This is usually faster for many small files.
               **Important:** TAR mode is **not resumable**. If interrupted, re-run the transfer.
               For best-effort resume, use pull mode with -Resume.

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
    Pull mode only: per-file copy and **skip** existing files with identical size.

.PARAMETER MaxRetries
    Tar-to-file mode: retry count for tar stream (default 2).

.PARAMETER StreamTar
    Tar mode: stream directly to extractor (adb exec-out ... | tar -xf -) to avoid creating a temporary .tar.
    Reduces disk space requirement (no ~2x footprint). **Not resumable** if interrupted.

.PARAMETER Verify
    If set, prints a summary table of file counts/sizes after transfer:
      - Local count/size under copied/extracted root.
      - Best-effort remote file count via adb (find|wc -l).
      - Remote size if known.

.PARAMETER ProgressIntervalSeconds
    Polling interval (seconds) for pull mode progress (default 5). Higher values reduce I/O overhead.

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/DCIM/Camera" -Dest "D:\Phone\Camera" -Mode tar -ShowProgress -PrecheckSpace -StreamTar -Verify

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/Download" -Dest "C:\Phone\Download" -Mode pull -Resume -ShowProgress -Verify

.NOTES
    Works on Windows PowerShell 5.1 and PowerShell 7+.
    Uses approved verb naming (Test-/Confirm-/Get-).
    Author: Manoj Bhaskaran
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
    Uses Get-Command to locate 'adb'. Throws a terminating error if not found.
.OUTPUTS
    None. Throws on failure.
.NOTES
    Install Android SDK Platform-Tools and add its folder to PATH.
#>
  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if (-not $adb) { throw "adb.exe not found. Install Platform-Tools and add to PATH." }
}

function Confirm-Device {
<#
.SYNOPSIS
    Confirms an authorized Android device is connected.
.DESCRIPTION
    Runs 'adb devices' and checks for a line ending with 'device'. If the device shows 'unauthorized' or nothing, throws guidance.
.OUTPUTS
    None. Throws on failure.
.NOTES
    Ensure the phone is unlocked and USB debugging is enabled/authorized.
#>
  $out = adb devices | Select-String "device`$"
  if (-not $out) {
    throw "No authorized device. Check cable, unlock phone, enable USB debugging, and allow this PC."
  }
}

function Test-HostTar {
<#
.SYNOPSIS
    Verifies tar.exe is available on Windows when Mode = tar.
.DESCRIPTION
    Ensures 'tar' can be invoked from PATH; otherwise suggests switching to pull mode or installing tar.
.OUTPUTS
    None. Throws on failure if Mode = tar.
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
    Attempts 'tar', then 'toybox tar', then 'busybox tar'. Returns success if any respond; otherwise throws.
.OUTPUTS
    None. Throws on failure if Mode = tar.
.NOTES
    Most modern Androids have toybox with tar.
#>
  if ($Mode -ne 'tar') { return }
  $cmd = "tar --version >/dev/null 2>&1 || toybox tar --help >/dev/null 2>&1 || busybox tar --help >/dev/null 2>&1; echo $?"
  $rc = (adb shell $cmd).Trim()
  if ($rc -ne '0') {
    throw "Phone-side tar not found. Switch to -Mode pull."
  }
}

function Get-RemoteSize {
<#
.SYNOPSIS
    Returns total bytes for a remote (phone) path (best-effort, awk-free).
.DESCRIPTION
    Prefers 'du' (native/toybox/busybox). Falls back to summing file sizes via 'stat' in a find loop.
    Avoids awk and avoids 'sh -lc' to prevent quoting issues on toybox shells.
.PARAMETER RemoteParent
    Parent directory (POSIX path), e.g., /sdcard/DCIM.
.PARAMETER RemoteLeaf
    Leaf entry (file or directory), e.g., Camera.
.OUTPUTS
    [Int64] total size in bytes (0 if unknown/error).
.NOTES
    This may take time on very large trees when falling back to find+stat.
#>
  param([string]$RemoteParent, [string]$RemoteLeaf)

  $remotePath = "$RemoteParent/$RemoteLeaf"
  # Single-quoted here-string preserved; we inject the path by placeholder replacement to avoid escaping hell.
  $script = @'
path="__REMOTE_PATH__"

# Prefer du; parse first field with "set --" to avoid awk dependency
if du -sb "$path" >/dev/null 2>&1; then
  set -- $(du -sb "$path"); echo "$1"; exit 0
fi
if command -v toybox >/dev/null 2>&1 && toybox du -b "$path" >/dev/null 2>&1; then
  set -- $(toybox du -b "$path"); echo "$1"; exit 0
fi
if command -v busybox >/dev/null 2>&1 && busybox du -s "$path" >/dev/null 2>&1; then
  set -- $(busybox du -s "$path"); echo $(( $1 * 1024 )); exit 0
fi

# Fall back: sum file sizes with stat
sum=0
if command -v stat >/dev/null 2>&1; then
  find "$path" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    sz=$(stat -c %s "$f" 2>/dev/null || echo 0)
    sum=$(( sum + ${sz:-0} ))
  done
  echo "$sum"; exit 0
fi

if command -v toybox >/dev/null 2>&1; then
  find "$path" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    sz=$(toybox stat -c %s "$f" 2>/dev/null || echo 0)
    sum=$(( sum + ${sz:-0} ))
  done
  echo "$sum"; exit 0
fi

if command -v busybox >/dev/null 2>&1; then
  find "$path" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    sz=$(busybox stat -c %s "$f" 2>/dev/null || echo 0)
    sum=$(( sum + ${sz:-0} ))
  done
  echo "$sum"; exit 0
fi

echo 0
'@
  $cmd = $script.Replace('__REMOTE_PATH__', $remotePath)

  try {
    $bytesText = (adb shell $cmd)
    $bytes = [int64]($bytesText.Trim())
    if ($bytes -lt 0) { 0 } else { $bytes }
  } catch { 0 }
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
  $parent = ([System.IO.Path]::GetDirectoryName($PosixPath.Replace('/','\'))).Replace('\','/')
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

function Get-RemoteFileCount {
<#
.SYNOPSIS
    Best-effort count of remote (phone) files for a given path.
.DESCRIPTION
    Uses find | wc -l via toybox/busybox if needed. Returns 0 if unavailable.
.PARAMETER RemoteParent
    Parent directory on the device (POSIX).
.PARAMETER RemoteLeaf
    Leaf (file or directory) name on the device.
.OUTPUTS
    [Int64] count (0 if unknown).
#>
  param([string]$RemoteParent, [string]$RemoteLeaf)

  $remotePath = "$RemoteParent/$RemoteLeaf"
  $script = @'
path="__REMOTE_PATH__"
if command -v find >/dev/null 2>&1; then
  find "$path" -type f 2>/dev/null | wc -l
elif command -v toybox >/dev/null 2>&1; then
  toybox find "$path" -type f 2>/dev/null | wc -l
elif command -v busybox >/dev/null 2>&1; then
  busybox find "$path" -type f 2>/dev/null | wc -l
else
  echo 0
fi
'@
  $cmd = $script.Replace('__REMOTE_PATH__', $remotePath)

  try {
    [int64]((adb shell $cmd).Trim())
  } catch { 0 }
}

Write-Verbose "Destination: $Dest"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Pre-checks
Test-Adb
Confirm-Device
Test-HostTar
Test-PhoneTar

# Common path split & remote size (for progress/space checks)
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
    $listCmd = "find ""$PhonePath"" -type f -print0 2>/dev/null | xargs -0 stat -c ""%s`t%n"" 2>/dev/null"
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
        Write-Host ("{0}: Retrying..." -f $ts)
      }
    }
  }
}
