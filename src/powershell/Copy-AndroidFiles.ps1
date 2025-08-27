<#
.SYNOPSIS
    Fast Android → PC transfer via ADB (pull or TAR stream) with progress, space checks, and resume.

.VERSION
    1.2.0

.CHANGELOG
    1.2.0
      - Added disk space precheck (-PrecheckSpace, -SpaceMarginPercent).
      - Pull mode resume (-Resume): skip existing files with same size.
      - Tar mode resilience: -MaxRetries, cleanup of partial .tar.
      - Optional streaming tar extraction (-StreamTar) to avoid double storage.
    1.1.0
      - Phone-side tar check, progress for tar, optional progress for pull.
    1.0.0
      - Initial version.

.DESCRIPTION
    Copies files/folders from an Android phone (e.g., Samsung S23) to a Windows PC using ADB.
    Modes:
      - pull : adb pull (simple mirroring). Optional approximate progress; optional -Resume.
      - tar  : adb exec-out tar → stream a single .tar (to file or directly to extractor), then extract.

.PARAMETER PhonePath
    Android path as seen by ADB (NOT Windows "This PC"). E.g. /sdcard/DCIM/Camera

.PARAMETER Dest
    PC destination folder (created if missing).

.PARAMETER Mode
    'pull' or 'tar'.

.PARAMETER ShowProgress
    If set: tar shows size-based progress; pull shows approximate progress.

.PARAMETER PrecheckSpace
    If set (default), validates destination free space before transfer.

.PARAMETER SpaceMarginPercent
    Extra headroom for space checks (default 10).

.PARAMETER Resume
    Pull mode: copy file-by-file and skip existing files with matching size.

.PARAMETER MaxRetries
    Tar mode: retry count for tar stream (default 2).

.PARAMETER StreamTar
    Tar mode: stream directly to extractor (adb exec-out ... | tar -xf -) to avoid temp .tar (saves space).

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/DCIM/Camera" -Dest "D:\Phone\Camera" -Mode tar -ShowProgress -PrecheckSpace -StreamTar

.EXAMPLE
    .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/Download" -Dest "C:\Phone\Download" -Mode pull -Resume -ShowProgress
#>

[CmdletBinding()]
param(
  [Parameter()] [string]$PhonePath = "/sdcard/Pictures/A_DownloaderForInstagram",
  [Parameter()] [string]$Dest      = "C:\Users\manoj\OneDrive\Desktop\New folder",
  [Parameter()] [ValidateSet('pull','tar')] [string]$Mode = 'tar',
  [Parameter()] [switch]$ShowProgress,
  [Parameter()] [switch]$PrecheckSpace = $true,
  [Parameter()] [int]$SpaceMarginPercent = 10,
  [Parameter()] [switch]$Resume,
  [Parameter()] [int]$MaxRetries = 2,
  [Parameter()] [switch]$StreamTar
)

$ErrorActionPreference = 'Stop'

function Test-Adb {
  <# .SYNOPSIS Verifies adb.exe is available. #>
  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if (-not $adb) { throw "adb.exe not found. Install Platform-Tools and add to PATH." }
}

function Confirm-Device {
  <# .SYNOPSIS Confirms an authorized device is connected. #>
  $out = adb devices | Select-String "device`$"
  if (-not $out) { throw "No authorized device. Check cable, unlock phone, enable USB debugging, and allow this PC." }
}

function Test-HostTar {
  <# .SYNOPSIS Verifies tar.exe on Windows when Mode = tar. #>
  if ($Mode -eq 'tar') {
    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) { throw "Windows tar.exe not found. Use -Mode pull or install tar and add to PATH." }
  }
}

function Test-PhoneTar {
  <# .SYNOPSIS Verifies phone-side tar (tar/toybox/busybox) for tar mode. #>
  if ($Mode -ne 'tar') { return }
  $cmd = 'sh -lc ''(tar --version >/dev/null 2>&1) || (toybox tar --help >/dev/null 2>&1) || (busybox tar --help >/dev/null 2>&1); echo $?'''
  $rc = (adb shell $cmd).Trim()
  if ($rc -ne '0') { throw "Phone-side tar not found. Switch to -Mode pull." }
}

function Get-RemoteSize {
  <#
  .SYNOPSIS Returns total bytes for $PhonePath (best-effort).
  .OUTPUTS [Int64] total bytes (0 if unknown).
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
  <# .SYNOPSIS Returns bytes for local directory (approx progress). #>
  param([string]$Path)
  try {
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    return ([int64]($sum ? $sum : 0))
  } catch { return 0 }
}

function Get-DriveFreeBytes {
  <# .SYNOPSIS Returns free bytes on the drive containing the given path. #>
  param([string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $drive = (Get-Item $resolved).PSDrive
  return [int64]$drive.Free
}

function Split-RemotePath {
  <# .SYNOPSIS Splits a POSIX path into parent + leaf for tar -C. #>
  param([string]$PosixPath)
  $parent = ([System.IO.Path]::GetDirectoryName($PosixPath.Replace('/','\'))).Replace('\','/')
  if ([string]::IsNullOrEmpty($parent)) { $parent = "/" }
  $leaf = ([System.IO.Path]::GetFileName($PosixPath))
  return @($parent, $leaf)
}

Write-Verbose "Destination: $Dest"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Pre-checks
Test-Adb
Confirm-Device
Test-HostTar
Test-PhoneTar

# Common path split & remote size (for progress and space checks)
$parent, $leaf = Split-RemotePath -PosixPath $PhonePath
$totalBytes = Get-RemoteSize -RemoteParent $parent -RemoteLeaf $leaf

# Disk space precheck
if ($PrecheckSpace -and $totalBytes -gt 0) {
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
    # Build file list on phone: size \t path
    $listCmd = "sh -lc 'find ""$PhonePath"" -type f -print0 2>/dev/null | xargs -0 stat -c ""%s`t%n"" 2>/dev/null'"
    $lines = adb shell $listCmd | Select-String ".*" -Raw

    $count = 0; $copied = 0
    foreach ($line in ($lines -split "`r?`n")) {
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
  }
  else {
    Write-Host "ADB pull `"$PhonePath`" → `"$Dest`""
    if ($ShowProgress) {
      $destBefore = Get-LocalDirSize -Path $Dest
      $proc = Start-Process adb -ArgumentList @('pull',"$PhonePath","$Dest") -NoNewWindow -PassThru
      while (-not $proc.HasExited) {
        Start-Sleep -Seconds 2
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
  }

}
else {
  # TAR mode
  if ($StreamTar) {
    Write-Host "Streaming TAR directly to extractor (no temp .tar): `"$PhonePath`" → `"$Dest`""
    # Progress while streaming: we can’t easily peek stdin size of tar.exe; show simple timer/MB written if desired.
    # Use cmd.exe to handle the pipe (PowerShell piping to tar.exe stdin can be quirky across versions).
    $cmd = "adb exec-out tar -C '$parent' -cf - '$leaf' | tar -xf - -C '$Dest'"
    if ($ShowProgress -and $totalBytes -gt 0) {
      Write-Host ("Estimated size: {0} MB" -f [math]::Round($totalBytes/1MB))
    }
    $rc = (cmd /c $cmd)
    # cmd /c returns combined output; errors will surface via tar's exit. We can’t directly capture exitcode here reliably.
    Write-Host "Streaming tar extraction finished. Verify contents."
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

        # Cleanup
        Remove-Item $tarFile -Force
        Write-Host "Done."
        break
      }
      catch {
        Write-Warning $_
        if (Test-Path $tarFile) { Remove-Item $tarFile -Force -ErrorAction SilentlyContinue }
        if ($attempt -ge $MaxRetries) { throw "Tar mode failed after $MaxRetries attempts." }
        Start-Sleep 2
        Write-Host "Retrying..."
      }
    }
  }
}
