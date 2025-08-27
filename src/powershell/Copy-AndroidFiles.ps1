<#
.SYNOPSIS
    Fast Android → PC transfer via ADB (pull or TAR stream).

.VERSION
    1.0.0

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

.EXAMPLE
    PS> .\Copy-AndroidFiles.ps1 -PhonePath "/sdcard/DCIM/Camera" -Dest "D:\Phone\Camera" -Mode tar

    Streams the Camera folder as a single TAR to D:\Phone\Camera\android_YYYYMMDD_HHMMSS.tar
    and then extracts it there.

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
  [string]$Mode = 'tar'
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

function Confirm-Adb {
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

function Test-Tar {
  <#
  .SYNOPSIS
      Verifies tar.exe is available when Mode = tar.
  .OUTPUTS
      None. Throws if not found.
  #>
  if ($Mode -eq 'tar') {
    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
      throw "tar.exe not found. Use Mode 'pull' or install tar and add it to PATH."
    }
  }
}

Write-Verbose "Destination: $Dest"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Pre-checks
Test-Adb
Confirm-Adb
Test-Tar

if ($Mode -eq 'pull') {
  Write-Host "ADB pull `"$PhonePath`" → `"$Dest`""
  adb pull "$PhonePath" "$Dest"
}
else {
  # TAR stream: pack on phone, write one file on PC, then extract
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $tarFile   = Join-Path $Dest ("android_{0}.tar" -f $timestamp)

  Write-Host "Streaming TAR from `"$PhonePath`" → `"$tarFile`""
  # Split path into parent + leaf for tar -C
  $parent = ([System.IO.Path]::GetDirectoryName($PhonePath.Replace('/','\'))).Replace('\','/')
  if ([string]::IsNullOrEmpty($parent)) { $parent = "/" }
  $leaf   = ([System.IO.Path]::GetFileName($PhonePath))

  # Run adb tar stream and write to tarFile
  Start-Process adb -ArgumentList @('exec-out','tar','-C',"$parent",'-cf','-',$leaf) `
    -RedirectStandardOutput $tarFile -NoNewWindow -Wait

  Write-Host "Extracting `"$tarFile`" → `"$Dest`""
  tar -xf $tarFile -C $Dest

  Write-Host "Done."
}
