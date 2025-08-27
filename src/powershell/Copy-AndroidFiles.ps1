<#
.SYNOPSIS
    Fast Android → PC transfer via ADB (pull or TAR stream) with progress.

.VERSION
    1.1.0

.CHANGELOG
    1.1.0
      - Added phone-side tar check (Test-PhoneTar).
      - TAR mode: precompute remote size, show Write-Progress, log final TAR size.
      - Pull mode: optional approximate progress via destination size polling (-ShowProgress).
      - Minor robustness and messaging.
    1.0.0
      - Initial version with pull and tar modes, ADB and PC tar checks, help.

.DESCRIPTION
    Copies files/folders from an Android phone (e.g., Samsung S23) to a Windows PC
    using Android Debug Bridge (ADB). This avoids MTP overhead and is much faster
    for large batches (e.g., 12K+ small files).

    Two modes:
      - pull : Uses 'adb pull' to mirror the folder to the PC (simple, reliable).
      - tar  : Streams one big TAR over ADB (adb exec-out tar ...) and then extracts
               on the PC. This is typically faster for many small files because it
               avoids per-file round trips.

.PARAMETER PhonePath
    The source path on the phone as seen by ADB (NOT the Windows “This PC\Phone” view).
    Common examples:
      /sdcard/DCIM/Camera
      /sdcard/DCIM/Screenshots
      /sdcard/Download
      /sdcard/Pictures
      /sdcard/WhatsApp/Media/WhatsApp Images
      /sdcard/WhatsApp/Media/WhatsApp Video

    How to discover your path:
      1) Ensure the phone is authorized (see PREREQUISITES).
      2) In PowerShell:
           adb shell
           ls /sdcard
           ls /sdcard/DCIM
           ls "/sdcard/WhatsApp/Media"
         Use the path that lists your files.

.PARAMETER Dest
    Destination folder on the PC. It will be created if missing.
    Example: D:\Phone\Camera

.PARAMETER Mode
    Transfer mode. One of: 'pull' or 'tar'
      pull = adb pull <PhonePath> <Dest>
      tar  = adb exec-out tar -C <parent> -cf - <leaf>  | write .tar on PC, then extract

.PARAMETER ShowProgress
    If set:
      - tar  : shows true size-based progress (bytes).
      - pull : shows approximate progress by polling dest folder size (adds some overhead).

.EXAMPLE
    PS> .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/DCIM/Camera" -Dest "D:\Phone\Camera" -Mode tar -ShowProgress

    Streams the Camera folder as a single TAR to D:\Phone\Camera\android_YYYYMMDD_HHMMSS.tar,
    shows progress, then extracts it there.

.EXAMPLE
    PS> .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/Download" -Dest "C:\Users\me\Downloads\Phone" -Mode pull

    Mirrors the /sdcard/Download folder to the given PC path.

.INPUTS
    None. Parameters only.

.OUTPUTS
    Writes progress and status to the console.

.PREREQUISITES
    1) Enable Developer Options (on the phone):
         Settings → About phone → Software information → tap "Build number" 7 times.
       Then open: Settings → Developer options.

    2) Enable USB debugging:
         Settings → Developer options → USB debugging = ON.

    3) Install Android Platform-Tools (ADB) on Windows:
         - Download the official "SDK Platform-Tools for Windows" ZIP from Google.
         - Extract to e.g. C:\platform-tools
         - Add that folder to PATH.
         - Verify in PowerShell:
             adb version

    4) Authorize this PC on the phone:
         - Connect via USB-C (prefer a USB 3.x cable/port).
         - Unlock the phone screen.
         - When prompted "Allow USB debugging?", tick "Always allow" and tap Allow.
         - Verify in PowerShell:
             adb devices
           Should show: <serial>   device

    5) Optional: Samsung USB driver (if Windows shows driver issues in Device Manager).

.TROUBLESHOOTING
    - adb devices shows "unauthorized":
        * Phone unlocked, try toggling Developer options → USB debugging OFF→ON.
        * Tap "Revoke USB debugging authorizations" (Developer options), replug cable.
        * Use a different USB-C cable/port (ensure USB 3.x, not charge-only).
        * On Windows: update the phone driver in Device Manager.

    - No 'tar' command found (tar mode):
        * Windows 10/11 normally include tar.exe. If not, install a tool like 7-Zip
          and use pull mode for now, or add tar.exe to PATH.

    - Slow transfers:
        * Keep phone screen awake and unlocked.
        * Prefer TAR mode for many small files.
        * Ensure the destination drive on PC has good free space and is an SSD if possible.

.NOTES
    Author: Manoj Bhaskaran
    Date:   2025-07-28
    Works on: Windows 10/11, PowerShell 5.1 and 7+
    Requires: adb.exe in PATH; for Mode 'tar', tar.exe in PATH (usually built-in)

.LINK
    Android Platform-Tools: https://developer.android.com/studio/releases/platform-tools
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$PhonePath = "/sdcard/Pictures/A_DownloaderForInstagram",

  [Parameter(Mandatory = $false)]
  [string]$Dest      = "C:\Users\manoj\OneDrive\Desktop\New folder",

  [Parameter(Mandatory = $false)]
  [ValidateSet('pull','tar')]
  [string]$Mode = 'tar',

  [Parameter(Mandatory = $false)]
  [switch]$ShowProgress
)

$ErrorActionPreference = 'Stop'

function Test-Adb {
  <#
  .SYNOPSIS
      Verifies adb.exe is available.
  .OUTPUTS
      None. Throws if not found.
  #>
  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if (-not $adb) { throw "adb.exe not found. Install Platform-Tools and add to PATH." }
}

function Confirm-Device {
  <#
  .SYNOPSIS
      Confirms an authorized device is connected.
  .OUTPUTS
      None. Throws if no authorized device is present.
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
  .OUTPUTS
      None. Throws if not found.
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
      Verifies phone-side tar (tar/toybox/busybox) is available when Mode = tar.
  .OUTPUTS
      None. Throws if not found.
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
      Returns total bytes for $PhonePath (best-effort, for progress).
  .OUTPUTS
      [Int64] total bytes (0 if unknown).
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
      Returns total bytes for a local directory (approx progress for pull).
  .OUTPUTS
      [Int64] total bytes (0 if unknown).
  #>
  param([string]$Path)
  try {
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    return ([int64]($sum ? $sum : 0))
  } catch { return 0 }
}

Write-Verbose "Destination: $Dest"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Pre-checks
Test-Adb
Confirm-Device
Test-HostTar
Test-PhoneTar

if ($Mode -eq 'pull') {
  Write-Host "ADB pull `"$PhonePath`" → `"$Dest`""
  if ($ShowProgress) {
    # Attempt an approximate progress bar
    $parent = ([System.IO.Path]::GetDirectoryName($PhonePath.Replace('/','\'))).Replace('\','/')
    if ([string]::IsNullOrEmpty($parent)) { $parent = "/" }
    $leaf   = ([System.IO.Path]::GetFileName($PhonePath))
    $totalBytes = Get-RemoteSize -RemoteParent $parent -RemoteLeaf $leaf

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
    Write-Host "Pull complete."
  } else {
    adb pull "$PhonePath" "$Dest"
  }
}
else {
  # TAR stream: pack on phone, write one file on PC, then extract
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $tarFile   = Join-Path $Dest ("android_{0}.tar" -f $timestamp)

  # Split path into parent + leaf for tar -C
  $parent = ([System.IO.Path]::GetDirectoryName($PhonePath.Replace('/','\'))).Replace('\','/')
  if ([string]::IsNullOrEmpty($parent)) { $parent = "/" }
  $leaf   = ([System.IO.Path]::GetFileName($PhonePath))

  $totalBytes = 0
  if ($ShowProgress) {
    $totalBytes = Get-RemoteSize -RemoteParent $parent -RemoteLeaf $leaf
  }

  Write-Host "Streaming TAR from `"$PhonePath`" → `"$tarFile`""
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
  Write-Host "Done."
}
