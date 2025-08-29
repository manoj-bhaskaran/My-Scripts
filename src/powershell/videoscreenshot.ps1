<#
.SYNOPSIS
Captures video frames from VLC or the desktop and (optionally) runs a Python cropper.

.DESCRIPTION
Plays each video file via VLC and saves periodic screenshots to a target folder.
Two capture approaches are supported:
  1) Desktop capture via GDI+ (default) – generic, no VLC filters required.
  2) VLC scene snapshots (opt-in via -UseVlcSnapshots) – captures only the video frame.

Major behaviours and safeguards:
  - Processed log: defaults to <SaveFolder>\processed_videos.log.
    If the log cannot be created or written to, the script terminates with an error.
  - Cleanup registry: a temporary PID registry file (.vlc_pids.txt) is written in
    <SaveFolder> to ensure VLC is terminated on Ctrl+C and shell exit.
  - Time limit: if reached, no new videos are started, but the current video finishes.
    Videos that complete successfully are logged as processed.
  - Process cleanup: VLC is closed or killed on all exit paths (normal, time/video limit, error).
  - Exit codes: non-zero VLC exit codes are treated as failures and not logged as processed.
  - Paths: Python cropper script path is parameterised; defaults relative to this script.
  - Resume file validation: in -CropOnly mode, the resume file must exist or the script errors.
  - Startup monitoring: waits up to VlcStartupTimeoutSeconds for VLC to initialise.
  - Debug logging: enable with the common -Debug switch (Write-Debug traces).
  - Capture modes:
    • GDI+ (desktop) — simple screen grabs; add -GdiFullscreen to force VLC full-screen;
    add -Legacy1080p to capture a fixed 1920×1080 region (legacy behavior).
    • VLC snapshots — headless, video-frame-only capture (no desktop/UI chrome).
  - Snapshot hygiene: opt-in -ClearSnapshotsBeforeRun deletes old <Video>_*.png before each run.
  - Interrupt-safe cleanup: pressing Ctrl+C triggers a graceful shutdown path that
    terminates any VLC processes launched by this script and then exits cleanly.


.PARAMETER SourceFolder
Folder containing input videos. Recurses by default.

.PARAMETER SaveFolder
Destination folder for screenshots. Default: Desktop\Screenshots
This folder is created if missing and also hosts the default processed log
(ProcessedLogPath) and the temporary PID registry (.vlc_pids.txt).

.PARAMETER FramesPerSecond
Time-based capture rate for screenshots per second (applies to both GDI+ and VLC snapshot modes).
Specifies how many screenshots are captured per second while VLC plays at native speed.

.PARAMETER TimeLimitSeconds
Maximum global time for video processing and capture in seconds. Once reached, no new videos are started, but the current video finishes. 0 = unlimited. Default: 0.

.PARAMETER VideoLimit
Maximum number of videos to process this run. 0 = unlimited. Default: 0. Both TimeLimitSeconds and VideoLimit are honored (whichever happens first) if provided.

.PARAMETER CropOnly
Skips video playback and runs the Python cropper only.

.PARAMETER ResumeFile
Name or path of a previously saved frame list (or other cropper resume file).
Validated when -CropOnly is used.

.PARAMETER PythonScriptPath
Path to the Python cropper script. Defaults to src\python\crop_colours.py
under the current script folder.

.PARAMETER ProcessedLogPath
Path to the file tracking processed videos.
If omitted, defaults to <SaveFolder>\processed_videos.log.
If a bare filename or relative path is provided, it is resolved under <SaveFolder>.
Creation/write failures are terminating errors.

.PARAMETER UseVlcSnapshots
Use VLC scene filter for frame capture instead of desktop GDI+ capture.

.PARAMETER VlcStartupTimeoutSeconds
Seconds to wait for VLC to start before considering it failed. Default: 10.

.PARAMETER GdiFullscreen
For GDI+ capture: launch VLC in full-screen, on-top, and minimal UI
(--fullscreen --video-on-top --qt-minimal-view). Use this to avoid small window
captures and to minimize chrome (menus/toolbars) in screenshots.

.PARAMETER Legacy1080p
Capture a fixed 1920x1080 rectangle from the top-left of the primary display
(legacy behavior from v1.0). Combine with -GdiFullscreen to reproduce the old
“full-screen 1080p desktop grab” method. Ignored in VLC snapshot mode.

.PARAMETER ClearSnapshotsBeforeRun
When -UseVlcSnapshots is active, delete any existing snapshot files for the
current video’s prefix (<VideoBaseName>_*.png) in SaveFolder before starting
VLC. Useful to avoid mixing frames across runs. Disabled by default.

.PARAMETER AutoStopGraceSeconds
Extra seconds added to detected video duration when auto-stopping VLC. Default 2.
This per-video upper bound is enforced regardless of whether a global limit is set.

.PARAMETER DisableAutoStop
Disable duration-based auto-stop; rely on VLC exit or -TimeLimitSeconds.

.INPUTS
None. You cannot pipe input to this script.

.OUTPUTS
None. Writes status/progress to the console and log files.

.EXAMPLE
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -FramesPerSecond 2 -TimeLimitSeconds 600 -Debug

.EXAMPLE
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -UseVlcSnapshots -TimeLimitSeconds 300

.EXAMPLE
.\videoscreenshot.ps1 -CropOnly -ResumeFile "resume_list.txt"

.EXAMPLE
# Legacy full-screen desktop capture (matches v1.0 behavior)
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -FramesPerSecond 2 -GdiFullscreen -Legacy1080p

.EXAMPLE
# GDI+ capture at current screen size, but ensure VLC is full-screen/on-top
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -FramesPerSecond 2 -GdiFullscreen

.EXAMPLE
# VLC snapshot mode (video-frame-only; no desktop chrome)
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -UseVlcSnapshots

.EXAMPLE
# Snapshot mode with clean slate per video
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -UseVlcSnapshots -ClearSnapshotsBeforeRun

.NOTES
AUTHOR
  Manoj Bhaskaran

VERSION
  1.2.7

CHANGELOG
  1.2.7
  - Fix: Updated Major behaviours documentation to correctly describe global time limit behavior 
    (prevents starting new videos rather than terminating current video mid-capture)
  - Fix: Added missing -File parameter to postCount query for consistency with preCount query
  - Cleanup: Removed unused $partial variable that was no longer needed after global time limit logic changes

  1.2.6
  - Fix: Corrected invalid Write-Debug call that incorrectly used -Level parameter
  - Fix: Updated SaveFolder parameter documentation to reflect correct default location (Desktop\Screenshots)
  
  1.2.5
  - Fix: Short video clips that complete during VLC startup window (ExitCode=0) are now correctly 
    treated as successful completion rather than startup failures
  - Fix: Corrected string quoting for --scene-fps parameter to ensure proper variable expansion 
    in VLC snapshot mode arguments

  1.2.4
  - Fix: FramesPerSecond now properly implemented for VLC snapshot mode using --scene-fps instead of --scene-ratio=1
    This ensures time-based capture cadence (N screenshots per second) rather than frame-count based capture
  - Fix: SaveFolder default changed from script-relative path to Desktop\Screenshots for better user experience
  - Fix: Per-video auto-stop grace period now always enforced regardless of global TimeLimitSeconds setting
  - Fix: GDI+ capture mode now respects per-video time limits with proper deadline checking
  - Improvement: Better separation of concerns between global time limits and per-video duration controls
  
  1.2.3
  - FramesPerSecond now applies to VLC snapshot mode using --scene-ratio based on assumed 30 FPS video.
  - TimeLimitSeconds is now a global limit: stops starting new videos once reached, but allows current video to finish.
  - VideoLimit and TimeLimitSeconds are honored together (whichever first).
  - Fix: Removed unused $started variable in main flow for better code hygiene.
  - Docs: updated parameter descriptions and FAQs for these changes.

  1.2.2
  - Fix: treat clean early VLC exit during the startup wait as normal (short clips),
    preventing false "failed to start" and avoiding erroneous errorDuringCapture.
  - Hardening: add --no-loop and --no-repeat to VLC args to neutralize user loop/repeat prefs.
  - Docs: clarify Start-Vlc behavior for short clips and note loop flags; add troubleshooting note.

  1.2.1
  - Auto-stop playback at detected video duration (+ grace) to prevent long
    runs producing blank screens when VLC doesn’t exit cleanly.
    • Enabled by default when -TimeLimitSeconds is 0.
    • Disable with -DisableAutoStop.
    • Grace seconds controlled by -AutoStopGraceSeconds (default: 2).
  - Start-Vlc now passes --stop-time <seconds> when duration is known, and
    also adds --no-loop and --no-repeat for safety.
  - New parameters:
    • -AutoStopGraceSeconds <int>   # extra seconds beyond detected duration
    • -DisableAutoStop              # opt out of duration-based stop
  - Docs: added .PARAMETER entries for the two new flags and a
    TROUBLESHOOTING note about “screenshots continue after short clips”.

  1.2.0
  - Default processed log now resolves under <SaveFolder> as processed_videos.log when -ProcessedLogPath
    is omitted. Bare filenames/relative paths resolve under <SaveFolder>.
  - Log create/append failures are terminating errors (exit 1).
  - PID-registry: write <SaveFolder>\.vlc_pids.txt; Ctrl+C and PowerShell.Exiting handlers terminate
    only PIDs launched by this run; entries are removed after Stop-Vlc.
  - Start-Vlc: write PID to registry; surface VLC stderr on failed start (shown with -Debug).

  1.1.12
  - Robust interrupt cleanup: track launched VLC PIDs and terminate them on Ctrl+C (Console.CancelKeyPress)
    and on PowerShell session exit (PowerShell.Exiting).

  1.1.11
  - Start-Vlc: correct argument logging (was logging $args instead of $vlcArgs).

  1.1.10
  - Invoke-Cropper: enforce Python 3.9+.
  - New -ClearSnapshotsBeforeRun (snapshot mode): delete existing <VideoBaseName>_*.png before start.

  1.1.9
  - Add -GdiFullscreen to force legacy full-screen VLC window in GDI+ capture.
  - Add -Legacy1080p to capture fixed 1920×1080 region (legacy method).
  - GDI+ launch uses GUI interface; snapshots still use --intf dummy.

  1.1.7
  - Post-capture: run crop_colours.py against SaveFolder when not -CropOnly
    ( --input <SaveFolder> --skip-bad-images --allow-empty --recurse [+ --resume-file] ).

  1.1.3
  - Fix: avoid scoped-variable parse issue by delimiting ${Path} in Add-ContentWithRetry.

  1.1.2
  - Retry appends to processed log; guard against truncation by creating the log only if missing.
  - GDI+ filenames: prefix with <VideoBaseName>_ to avoid cross-video collisions.
  - VLC startup: single restart attempt if VLC exits during startup.

  1.1.1
  - Snapshot mode: per-video --scene-prefix (<VideoBaseName>_) to avoid collisions.
  - Post-run validation: ensure frames were actually saved (snapshot pre/post counts; GDI+ counter).
  - Robustness: retry GDI+ frame saves; single retry for Python cropper.

  1.1.0
  - Time-limit terminates VLC and prevents false “processed” logging.
  - Centralized cleanup: VLC closed/killed on all exit paths; non-zero VLC exit codes mark failure.
  - Add -PythonScriptPath; validate -ResumeFile in -CropOnly; startup timeout for VLC; optional snapshot mode.

  EXIT CODES
    0  Success
    1  Runtime error (processing/cropper failure, or log create/write failure)
    2  Usage/validation error (invalid paths, resume file not found, etc.)

  PREREQUISITES
  - VLC installed and in PATH (vlc.exe).
  - Python available if running the cropper; cropper script present.

TROUBLESHOOTING
  - Blank images: ensure VLC can decode the file; try -UseVlcSnapshots.
  - VLC not starting: increase -VlcStartupTimeoutSeconds; verify codecs.
  - Crop-only errors: check -ResumeFile path; ensure Python & script path are correct.
  - To see detailed diagnostic output, run with -Debug to enable Write-Debug traces.
  - Screenshots are tiny or include menus:
      • Use -GdiFullscreen for GDI+ capture to force VLC full-screen/on-top.
      • For exact video frames without desktop/UI, use -UseVlcSnapshots.
      • To replicate v1.0 behavior exactly, combine -GdiFullscreen with -Legacy1080p.
  - Wrong resolution:
      • GDI+ (default) uses your current primary screen size; use -Legacy1080p for fixed 1920×1080,
        or switch to snapshot mode to avoid desktop resolution altogether.
  - Multi-monitor/DPI issues:
      • Ensure VLC is displayed on the primary monitor or move it there; GDI+ grabs the primary screen by default.
      • Disable Windows scaling on VLC if coordinates appear offset.
  - Ctrl+C leaves VLC open:
      • From v1.1.12, the script tracks VLC PIDs it launched and terminates them
        on Ctrl+C (Console.CancelKeyPress) and on shell exit (PowerShell.Exiting).
      • If VLC still remains, check for other VLC instances started outside the script.
        Only PIDs launched by this script are terminated.
  - Log file errors: The processed log defaults to <SaveFolder>\processed_videos.log.
    If creation or append fails (permissions/locks), the run terminates (exit 1).
  - Stale .vlc_pids.txt: If a previous run crashed, you may see this file in <SaveFolder>.
    It is safe to delete; it will be recreated on the next run.
  - Screenshots continue long after short clips: ensure auto-stop is enabled (default) or set -TimeLimitSeconds.
  - Very short clips exit during startup:
      • This is normal. From v1.2.2, a clean early exit (ExitCode=0) during the startup wait is
        treated as successful playback completion, not a start failure.

FAQS
  Q: No frames were captured—what should I check?
     A: Confirm VLC can play the file (codecs), ensure write permission to SaveFolder,
        and verify free disk space. In snapshot mode, confirm scene prefix uniqueness.
  Q: How do I reduce the number of saved frames?
     A: Lower -FramesPerSecond (GDI+ mode) or use -TimeLimitSeconds to bound duration.
  Q: VLC is installed but not detected.
     A: Run `vlc --version` from the same PowerShell session; add VLC to PATH if needed.
  Q: Python cropper fails to start.
     A: Run `python --version`; ensure Python is on PATH and version is compatible.
  Q: Why do I see the VLC title/menu bar in screenshots?
  A: For GDI+ capture, add -GdiFullscreen, or switch to -UseVlcSnapshots which captures only the video frame.

  Q: How do I get the exact legacy screenshots I used before?
  A: Run with -GdiFullscreen -Legacy1080p (full-screen VLC + fixed 1920×1080 desktop grabs).

  Q: What’s the difference between GDI+ and snapshot mode?
  A: GDI+ captures the desktop (quick to set up; may include UI). Snapshot mode uses VLC’s scene filter to save only the video content (no UI), typically cleaner for analysis.

  Q: I stopped the script with Ctrl+C but VLC stayed open—why?
  A: Prior to v1.1.12, Ctrl+C could abort before the normal cleanup ran. From v1.1.12,
   the script registers handlers that terminate VLC PIDs launched by this run.
   Note: VLC started outside the script is not touched.

  Q: Will this kill other VLC windows I opened manually?
  A: No. Only VLC processes started by this script (tracked PIDs) are terminated.

  Q: Where is the processed log stored by default?
  A: In <SaveFolder>\processed_videos.log. A bare filename for -ProcessedLogPath is
     also created under <SaveFolder>.

  Q: Why did the script abort with a log write error?
  A: Creating or appending the processed log is mandatory. Fix folder permissions,
   disk space, or pick a different SaveFolder/ProcessedLogPath.

  Q: Why does the script save to Desktop\Screenshots by default instead of the script folder?
  A: From v1.2.4, the default location is Desktop\Screenshots for better discoverability and 
     to avoid cluttering the script directory. Use -SaveFolder to specify a different location.

  Q: Does FramesPerSecond work the same way in both capture modes?
  A: Yes, from v1.2.4 both GDI+ and VLC snapshot modes use time-based capture (N shots per second)
     rather than frame-count based capture, ensuring consistent behavior.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceFolder = (Join-Path $PSScriptRoot 'videos'),

    [Parameter(Mandatory = $false)]
    [string]$SaveFolder = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Screenshots'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 60)]
    [int]$FramesPerSecond = 1,

    [Parameter(Mandatory = $false)]
    [int]$TimeLimitSeconds = 0,

    [Parameter(Mandatory = $false)]
    [int]$VideoLimit = 0,

    [Parameter(Mandatory = $false)]
    [switch]$CropOnly,

    [Parameter(Mandatory = $false)]
    [string]$ResumeFile,

    [Parameter(Mandatory = $false)]
    [string]$PythonScriptPath = (Join-Path $PSScriptRoot 'src\python\crop_colours.py'),

    [Parameter(Mandatory = $false)]
    [string]$ProcessedLogPath,

    [Parameter(Mandatory = $false)]
    [switch]$UseVlcSnapshots,

    [Parameter(Mandatory = $false)]
    [int]$VlcStartupTimeoutSeconds = 10,

    [Parameter(Mandatory = $false)]
    [switch]$GdiFullscreen,

    [Parameter(Mandatory = $false)]
    [switch]$Legacy1080p,

    [Parameter(Mandatory = $false)]
    [switch]$ClearSnapshotsBeforeRun,

    [Parameter(Mandatory = $false)]
    [int]$AutoStopGraceSeconds = 2,   # extra seconds added to detected duration

    [Parameter(Mandatory = $false)]
    [switch]$DisableAutoStop          # if set, skip duration-based auto-stop

)

# region Utilities

<#
.SYNOPSIS
Append to a file with limited retries to absorb transient locks.
.DESCRIPTION
Attempts Add-Content up to MaxAttempts with a simple linear backoff. Returns
$true on success, $false if all attempts fail.
.PARAMETER Path
Target file path (LiteralPath).
.PARAMETER Value
Text to append.
.PARAMETER MaxAttempts
Maximum attempts (default 3).
.EXAMPLE
Add-ContentWithRetry -Path $ProcessedLogPath -Value $video.FullName
.EXAMPLE
# Use default log in <SaveFolder>\processed_videos.log
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots"

.EXAMPLE
# Provide a bare filename; it is resolved under <SaveFolder>
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -ProcessedLogPath "new_processed_videos.log"

.EXAMPLE
# Provide a relative subpath; it is resolved under <SaveFolder>
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -ProcessedLogPath "logs\processed.log"

.EXAMPLE
# Provide an absolute path; used as-is
.\videoscreenshot.ps1 -SourceFolder "D:\clips" -SaveFolder "D:\shots" `
  -ProcessedLogPath "C:\logs\processed.log"
#>
function Add-ContentWithRetry {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Value,
        [int]$MaxAttempts = 3
    )
    for ($i=1; $i -le $MaxAttempts; $i++) {
        try { Add-Content -LiteralPath $Path -Value $Value; return $true }
        catch {
            if ($i -eq $MaxAttempts) { Write-Message -Level Error -Message "Failed to append to ${Path}: $($_.Exception.Message)"; return $false }
            Start-Sleep -Milliseconds (200 * $i) # linear backoff
        }
    }
}

<#
.SYNOPSIS
Simple structured console logging.
.DESCRIPTION
Writes coloured, prefixed messages for Info/Warn/Error with optional timestamps.
.PARAMETER Level
Log level: Info, Warn, Error.
.PARAMETER Message
Message text.
.EXAMPLE
Write-Message -Level Info -Message "Starting capture..."
#>
function Write-Message {
    param(
        [ValidateSet('Info','Warn','Error')]
        [string]$Level = 'Info',
        [Parameter(Mandatory)][string]$Message
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    switch ($Level) {
        'Info'  { Write-Host "[$ts] [INFO ] $Message" -ForegroundColor Cyan }
        'Warn'  { Write-Host "[$ts] [WARN ] $Message" -ForegroundColor Yellow }
        'Error' { Write-Host "[$ts] [ERROR] $Message" -ForegroundColor Red }
    }
}

# Ensure destination directories exist
New-Item -ItemType Directory -Path $SaveFolder -Force | Out-Null

# Resolve default log path to <SaveFolder>\processed_videos.log when not provided
if ([string]::IsNullOrWhiteSpace($ProcessedLogPath)) {
    # No value provided -> default in SaveFolder
    $ProcessedLogPath = Join-Path $SaveFolder 'processed_videos.log'
} elseif (-not [System.IO.Path]::IsPathRooted($ProcessedLogPath)) {
    # Bare filename or relative path -> resolve under SaveFolder
    $ProcessedLogPath = Join-Path $SaveFolder $ProcessedLogPath
}

# Ensure the log directory exists, create the file if missing, and verify writability.
try {
    $logDir = Split-Path -Parent $ProcessedLogPath
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
    }
    if (-not (Test-Path -LiteralPath $ProcessedLogPath)) {
        New-Item -ItemType File -Path $ProcessedLogPath -Force -ErrorAction Stop | Out-Null
    }
    # Writability test without modifying contents
    $fs = [System.IO.File]::Open(
        $ProcessedLogPath,
        [System.IO.FileMode]::Append,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::Read
    )
    $fs.Close()
} catch {
    Write-Message -Level Error -Message "Processed log must be creatable and writable: $ProcessedLogPath — $($_.Exception.Message)"
    exit 1
}

# PID registry used by event handlers (shared across runspaces)
$PidRegistry = Join-Path $SaveFolder '.vlc_pids.txt'
if (Test-Path -LiteralPath $PidRegistry) {
    Remove-Item -LiteralPath $PidRegistry -Force -ErrorAction SilentlyContinue
}

# Honor the common -Debug parameter from CmdletBinding
if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' }

# Load assemblies needed for GDI+ capture (PS7 on Windows supports System.Drawing)
Add-Type -AssemblyName System.Drawing | Out-Null
Add-Type -AssemblyName System.Windows.Forms | Out-Null

<#
.SYNOPSIS
Save a desktop frame with simple retries.

.DESCRIPTION
Calls Get-ScreenWithGDIPlus and retries on transient I/O errors with linear backoff.
If Width/Height are passed through, captures a fixed-size rectangle (e.g., legacy 1080p).

.PARAMETER TargetPath
Output PNG path.

.PARAMETER MaxAttempts
Maximum attempts (default 3).

.PARAMETER Width
Optional width to pass to Get-ScreenWithGDIPlus.

.PARAMETER Height
Optional height to pass to Get-ScreenWithGDIPlus.

.EXAMPLE
Save-FrameWithRetry -TargetPath 'C:\shots\frame.png'
.EXAMPLE
Save-FrameWithRetry -TargetPath 'C:\shots\frame.png' -Width 1920 -Height 1080
#>
function Save-FrameWithRetry {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [int]$MaxAttempts = 3,
        [int]$Width,
        [int]$Height
    )
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            if ($PSBoundParameters.ContainsKey('Width') -and $PSBoundParameters.ContainsKey('Height')) {
                Get-ScreenWithGDIPlus -TargetPath $TargetPath -Width $Width -Height $Height
            } else {
                Get-ScreenWithGDIPlus -TargetPath $TargetPath
            }
            return $true
        } catch {
            if ($i -eq $MaxAttempts) {
                Write-Message -Level Error -Message "Failed to save frame after $MaxAttempts attempts: $($_.Exception.Message)"
                return $false
            }
            Start-Sleep -Milliseconds (200 * $i)
        }
    }
}

<#
.SYNOPSIS
Return video duration in seconds using Windows property (if available).
#>
function Get-VideoDurationSeconds {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $shell  = New-Object -ComObject Shell.Application
        $folder = $shell.NameSpace((Split-Path -LiteralPath $Path))
        $item   = $folder.ParseName((Split-Path -Leaf -LiteralPath $Path))
        $v = $item.ExtendedProperty('System.Media.Duration')  # 100-ns units or "hh:mm:ss"
        if ($null -eq $v) { return $null }
        if ($v -is [string] -and $v.Trim()) { return [TimeSpan]::Parse($v).TotalSeconds }
        # 100-ns units
        return [double]$v / 10000000.0
    } catch { return $null }
}

# endregion Utilities

# region Capture helpers

<#
.SYNOPSIS
Start VLC for a single video file.

.DESCRIPTION
Launches vlc.exe configured for the selected capture mode:
  - GDI+ desktop capture: starts a GUI window. If -GdiFullscreen is set, VLC runs
    full-screen, on-top, with minimal UI to reduce chrome in screenshots.
  - Snapshot mode (-UseVlcSnapshots): starts headless (--intf dummy) and writes
    frames directly to disk (no desktop/UI captured).
  - Disables VLC loop/repeat via --no-loop and --no-repeat to avoid unintended replay due to user prefs.
  - A clean VLC exit (ExitCode=0) during the startup wait window is treated as a valid early completion
  (e.g., very short clips) and not a start failure.

This function also records the launched VLC PID so that the script can terminate
it on Ctrl+C (Console.CancelKeyPress) and on PowerShell session exit.

.PARAMETER VideoPath
Full path to the video file.

.PARAMETER SaveFolder
Destination folder for screenshots. Default: Desktop\Screenshots  
This folder is created if missing and also hosts the default processed log
(ProcessedLogPath) and the temporary PID registry (.vlc_pids.txt).

.PARAMETER UseVlcSnapshots
Enable VLC scene filter snapshots (headless capture, video-frame only).

.EXAMPLE
$proc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\shots'
.EXAMPLE
$proc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\shots' -UseVlcSnapshots
#>
function Start-Vlc {
    param(
        [Parameter(Mandatory)][string]$VideoPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [switch]$UseVlcSnapshots,
        [double]$StopAtSeconds = 0
    )

    # Args that are safe for both modes
    $common = @(
        '--no-qt-privacy-ask',
        '--no-video-title-show',
        '--no-loop',    # added in 1.2.2
        '--no-repeat',
        '--rate', '1',
        '--play-and-exit'
    )

    $vlcargs = @("`"$VideoPath`"")

    if ($StopAtSeconds -gt 0) {
        $vlcargs += @('--stop-time', [string]([int][Math]::Round($StopAtSeconds)))
    }

    if ($UseVlcSnapshots) {
        # Headless snapshots: no window needed
        $vlcargs += @(
            '--intf', 'dummy',
            '--video-filter=scene',
            "--scene-path=""$SaveFolder""",
            "--scene-prefix=""$([IO.Path]::GetFileNameWithoutExtension($VideoPath))_""",
            '--scene-format=png',
            "--scene-fps=$FramesPerSecond"
        )
    } else {
        # GDI+ desktop capture requires a visible window
        if ($GdiFullscreen) {
            $vlcargs += @('--fullscreen', '--video-on-top', '--qt-minimal-view')
        }
        # (no --intf dummy here; we want a GUI window)
    }

    $vlcargs += $common
    Write-Debug ("VLC args: " + ($vlcargs -join ' '))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = 'vlc'
    $psi.Arguments = ($vlcargs -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $null = $p.Start()
    $global:vlcPids += $p.Id
    Add-Content -LiteralPath $PidRegistry -Value $p.Id

    # Basic startup wait (window may be GUI or dummy)
    $deadline = (Get-Date).AddSeconds($VlcStartupTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($p.HasExited) { break }
        Start-Sleep -Milliseconds 200
    }

    if ($p.HasExited) {
        $stderr = $p.StandardError.ReadToEnd()
        if ($p.ExitCode -eq 0) {
            Write-Debug "VLC exited cleanly during startup window (short clip)."
            return $p  # treat as success; downstream checks verify frames
        }
        if ($DebugPreference -eq 'Continue' -and $stderr) { Write-Debug "VLC stderr: $stderr" }
        Write-Message -Level Error -Message "VLC failed to start. ExitCode=$($p.ExitCode). $stderr"
        return $null
    }

    Write-Debug "VLC started (PID $($p.Id))"
    return $p
}

<#
.SYNOPSIS
Stops VLC process gracefully, with force-kill fallback.

.DESCRIPTION
Attempts to close VLC via CloseMainWindow (no-op under --intf dummy),
waits briefly for exit, and then force-kills the process if still running.
Safe to call in finally blocks to ensure cleanup on all paths.

.PARAMETER Process
The VLC process object to stop.

.EXAMPLE
# Ensure VLC is cleaned up even on error paths
try {
  $vlc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\shots'
  # ... do work ...
} finally {
  if ($vlc) { Stop-Vlc -Process $vlc }
}
#>
function Stop-Vlc {
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process]$Process
    )
    try   { $null = $Process.CloseMainWindow() } catch {}
    try   { $Process.WaitForExit(5000) } catch {}
    if (-not $Process.HasExited) {
        Write-Debug "VLC still running; force killing PID $($Process.Id)"
        try { Stop-Process -Id $Process.Id -Force } catch {}
    }
}

<#
.SYNOPSIS
Capture the primary screen to a PNG file.

.DESCRIPTION
Uses System.Drawing to copy a region of the primary screen and save it to disk.
If Width/Height are provided, captures a fixed-size rectangle from (0,0).
Otherwise, captures the full primary screen (current resolution).

.PARAMETER TargetPath
Output PNG path.

.PARAMETER Width
Optional explicit width in pixels (e.g., 1920 for legacy).

.PARAMETER Height
Optional explicit height in pixels (e.g., 1080 for legacy).

.EXAMPLE
Get-ScreenWithGDIPlus -TargetPath 'C:\shots\frame.png'
.EXAMPLE
Get-ScreenWithGDIPlus -TargetPath 'C:\shots\frame.png' -Width 1920 -Height 1080
#>
function Get-ScreenWithGDIPlus {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [int]$Width,
        [int]$Height
    )
    if ($Width -and $Height) {
        $w = $Width; $h = $Height
    } else {
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $w = $bounds.Width; $h = $bounds.Height
    }
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0, 0, 0, 0, [System.Drawing.Size]::new($w, $h))
    $bmp.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

<#
.SYNOPSIS
Run the external Python cropper.

.DESCRIPTION
Invokes crop_colours.py v3.1.0 with:
  --input <SaveFolder> --skip-bad-images --allow-empty --recurse
If provided, --resume-file is validated; a relative path is resolved under <SaveFolder>.
Requires Python 3.9+; throws if lower.

.PARAMETER PythonScriptPath
Path to crop_colours.py.

.PARAMETER SaveFolder
Folder passed to --input.

.PARAMETER ResumeFile
Optional resume file; if relative, resolved under SaveFolder.

.EXAMPLE
Invoke-Cropper -PythonScriptPath .\src\python\crop_colours.py -SaveFolder .\Screenshots
#>
function Invoke-Cropper {
    <#
    .SYNOPSIS
    Runs the external Python cropper script.

    .DESCRIPTION
    Invokes crop_colours.py v3.1.0 with:
      --input <SaveFolder> --skip-bad-images --allow-empty --recurse
    and, if provided, --resume-file <ResumeFile> (relative paths resolved under SaveFolder).
    #>
    param(
        [Parameter(Mandatory)][string]$PythonScriptPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [string]$ResumeFile
    )

    # Require Python 3.9+ (handles both 'Python 3.x.y' and possible py launchers)
    $pv = (& python --version) 2>&1
    if ($pv -notmatch '^Python 3\.(9|[1-9][0-9])\.') {
        throw "Python 3.9+ required (found: $pv)"
    }

    if (-not (Test-Path -LiteralPath $PythonScriptPath)) {
        throw "PythonScriptPath not found: $PythonScriptPath"
    }

    # Build optional --resume-file (resolve relative path under SaveFolder)
    $resumeArg = @()
    if ($ResumeFile) {
        $resumePath = if ([System.IO.Path]::IsPathRooted($ResumeFile)) {
            $ResumeFile
        } else {
            Join-Path $SaveFolder $ResumeFile
        }
        if (-not (Test-Path -LiteralPath $resumePath)) {
            throw "Resume file not found: $resumePath"
        }
        # cropper v3.1.0 uses kebab-case --resume-file
        $resumeArg = @('--resume-file', "`"$resumePath`"")
    }

    # Required flags:
    #   --input <SaveFolder> --skip-bad-images --allow-empty --recurse
    $pyArgs = @(
        "`"$PythonScriptPath`"",
        '--input', "`"$SaveFolder`"",
        '--skip-bad-images',
        '--allow-empty',
        '--recurse'
    ) + $resumeArg

    Write-Debug ("Python args: " + ($pyArgs -join ' '))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'python'
    $psi.Arguments = ($pyArgs -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $null = $p.Start()

    # Only keep stdout when debugging; otherwise discard to avoid “assigned but unused”
    if ($DebugPreference -eq 'Continue') {
        $cropperStdout = $p.StandardOutput.ReadToEnd()
    } else {
        $null = $p.StandardOutput.ReadToEnd()
    }
    $cropperStderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($p.ExitCode -ne 0) {
        Write-Message -Level Error -Message "Cropper failed (ExitCode=$($p.ExitCode)). $cropperStderr"
        throw "Cropper failed."
    } else {
        if ($DebugPreference -eq 'Continue') { Write-Debug "Cropper output:`n$cropperStdout" }
        Write-Message -Level Info -Message "Cropper finished successfully."
    }
}

# endregion Capture helpers

# region Main flow

# Track VLC PIDs we start so we can clean them up on Ctrl+C or shell exit
$global:vlcPids = @()

# Clean up on Ctrl+C (Console.CancelKeyPress) and on session exit
$ctrlCHandler = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -SourceIdentifier CtrlCHandler -Action {
    try {
        $EventArgs.Cancel = $true
        Write-Host "[CTRL+C] Cleaning up VLC..." -ForegroundColor Yellow
        if (Test-Path -LiteralPath $using:PidRegistry) {
            Get-Content -LiteralPath $using:PidRegistry |
                ForEach-Object {
                    $id = $_.ToString().Trim()
                    if ($id -match '^\d+$') {
                        Stop-Process -Id [int]$id -Force -ErrorAction SilentlyContinue
                    }
                }
        }
    } catch {}
    [Environment]::Exit(1)
}

$exitHandler  = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    try {
        if (Test-Path -LiteralPath $using:PidRegistry) {
            Get-Content -LiteralPath $using:PidRegistry |
                ForEach-Object {
                    $id = $_.ToString().Trim()
                    if ($id -match '^\d+$') {
                        Stop-Process -Id [int]$id -Force -ErrorAction SilentlyContinue
                    }
                }
        }
    } catch {}
}

if ($CropOnly) {
    Write-Message -Level Info -Message "Crop-only mode."

    try {
        Invoke-Cropper -PythonScriptPath $PythonScriptPath -SaveFolder $SaveFolder -ResumeFile $ResumeFile
    } catch {
        Write-Message -Level Error -Message $_.Exception.Message
        exit 1
    }
    exit 0
}

if (-not (Test-Path -LiteralPath $SourceFolder)) {
    Write-Message -Level Error -Message "SourceFolder not found: $SourceFolder"
    exit 1
}

$videoExt = @('*.mp4','*.mkv','*.avi','*.mov','*.m4v','*.wmv')
$videos = Get-ChildItem -LiteralPath $SourceFolder -Recurse -File -Include $videoExt | Sort-Object FullName

if ($VideoLimit -gt 0) {
    $videos = $videos | Select-Object -First $VideoLimit
}

$processed = @()
try {
    $processed = Get-Content -LiteralPath $ProcessedLogPath -ErrorAction Stop
} catch {
    Write-Message -Level Error -Message "Failed to read processed log: $ProcessedLogPath — $($_.Exception.Message)"
    exit 1
}

$intervalMs = [int](1000 / [Math]::Max(1, $FramesPerSecond))

$globalStart = Get-Date
foreach ($video in $videos) {
    if ($TimeLimitSeconds -gt 0 -and ((New-TimeSpan -Start $globalStart -End (Get-Date)).TotalSeconds -ge $TimeLimitSeconds)) {
        Write-Message -Level Info -Message "Global time limit of $TimeLimitSeconds seconds reached; stopping processing."
        break
    }
    $already = $processed -contains $video.FullName
    if ($already) {
        Write-Message -Level Info -Message "Skipping (already processed): $($video.FullName)"
        continue
    }

    Write-Message -Level Info -Message "Processing: $($video.FullName)"
    $vlc = $null
    $errorDuringCapture = $false
    $savedThisRun = 0
    $hadFrames = $false
    $preCount = 0
    $scenePrefixForThisVideo = ([IO.Path]::GetFileNameWithoutExtension($video.FullName)) + '_'

    if ($UseVlcSnapshots) {
        if ($ClearSnapshotsBeforeRun) {
            # Remove old snapshots for this video’s prefix to start clean
            Get-ChildItem -LiteralPath $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            $preCount = 0
        } else {
            # Keep existing files; measure preCount so post-run validation still works
            $preCount = (Get-ChildItem -LiteralPath $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        }
    }

    try {
        $stopAt = 0
        if (-not $DisableAutoStop) {
            $dur = Get-VideoDurationSeconds -Path $video.FullName
            if ($dur -and $dur -gt 0) { $stopAt = [double]$dur + [double]$AutoStopGraceSeconds }
        }
        
        $vlc = Start-Vlc -VideoPath $video.FullName -SaveFolder $SaveFolder `
                    -UseVlcSnapshots:$UseVlcSnapshots -StopAtSeconds:$stopAt

        if (-not $vlc) {
            throw "Failed to start VLC for: $($video.FullName)"
        }

        if ($UseVlcSnapshots) {
            # In snapshot mode we just wait for VLC to finish or time out
            while (-not $vlc.HasExited) {
                Start-Sleep -Milliseconds 200
            }
        } else {
            # GDI+ desktop capture loop
            $frameIndex = 0
            $videoBase  = [IO.Path]::GetFileNameWithoutExtension($video.Name)

            # Add per-video deadline for GDI+ capture
            $perVideoDeadline = if ($stopAt -gt 0) { (Get-Date).AddSeconds($stopAt) } else { $null }

            while (-not $vlc.HasExited) {

                # Check per-video deadline in GDI+ capture loop
                if ($perVideoDeadline -and (Get-Date) -ge $perVideoDeadline) {
                    Write-Debug "Per-video time limit reached for: $($video.FullName)"
                    break
                }
                $filename = ('{0}_{1:D6}.png' -f $videoBase, $frameIndex) # avoid cross-video collisions
                $target   = Join-Path $SaveFolder $filename

                $okSave = if ($Legacy1080p) {
                    Save-FrameWithRetry -TargetPath $target -Width 1920 -Height 1080
                } else {
                    Save-FrameWithRetry -TargetPath $target
                }

                if ($okSave) {
                    if ($frameIndex -eq 0) { Write-Debug "First frame saved: $target" }
                    $frameIndex++
                    $savedThisRun++
                } else {
                    $errorDuringCapture = $true
                }
                Start-Sleep -Milliseconds $intervalMs
            }
        }
    }
    catch {
        $errorDuringCapture = $true
        Write-Message -Level Error -Message $_.Exception.Message
    }
    finally {
        if ($vlc) {
            Stop-Vlc -Process $vlc
            if (Test-Path -LiteralPath $PidRegistry) {
                (Get-Content -LiteralPath $PidRegistry | Where-Object { $_ -ne "$($vlc.Id)" }) |
                    Set-Content -LiteralPath $PidRegistry
            }
        }
    }

    # Evaluate outcome
    $vlcExit = if ($vlc) { $vlc.ExitCode } else { -1 }
    Write-Debug "VLC exit code: $vlcExit; hadErrors=$errorDuringCapture"

    # Post-run validation: ensure frames actually exist
    if ($UseVlcSnapshots) {
        # Compare pre/post counts for this video's prefix
        $postCount = (Get-ChildItem -LiteralPath $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $hadFrames = ($postCount -gt $preCount)
    } else {
        # GDI+: require at least one frame saved during this run
        $hadFrames = ($savedThisRun -gt 0)
    }

    # Final outcome: only mark processed when ALL conditions are true:
    # - no capture errors
    # - VLC exited cleanly (ExitCode 0)
    # - evidence of frames saved (hadFrames)
    $ok = (-not $errorDuringCapture) -and ($vlcExit -eq 0) -and $hadFrames

    if ($ok) {
        if (Add-ContentWithRetry -Path $ProcessedLogPath -Value $video.FullName) {
            Write-Message -Level Info -Message "Marked processed: $($video.FullName)"
        } else {
            Write-Message -Level Error -Message "Processed OK, but failed to update processed log: $ProcessedLogPath"
            exit 1
        }
    }
}

# Post-capture: run cropper over SaveFolder if not in CropOnly mode
# (mirrors original 1.0 behavior; uses v3.1.0 flags)
try {
    if (Get-ChildItem -LiteralPath $SaveFolder -Recurse -File -Include *.png, *.jpg, *.jpeg -ErrorAction SilentlyContinue | Select-Object -First 1) {
        Write-Message -Level Info -Message "Invoking crop_colours.py on $SaveFolder (post-capture)."
        Invoke-Cropper -PythonScriptPath $PythonScriptPath -SaveFolder $SaveFolder -ResumeFile $ResumeFile
    } else {
        Write-Message -Level Info -Message "No images found in $SaveFolder for cropping; skipping."
    }
} catch {
    # Match original spirit: log failure without terminating the entire run
    Write-Message -Level Error -Message "Post-capture cropper failed: $($_.Exception.Message)"
}

if ($ctrlCHandler) {
    Unregister-Event -SourceIdentifier CtrlCHandler
    Remove-Job $ctrlCHandler -Force -ErrorAction SilentlyContinue
}
if ($exitHandler) {
    Unregister-Event -SourceIdentifier PowerShell.Exiting
    Remove-Job $exitHandler -Force -ErrorAction SilentlyContinue
}

# Final cleanup: remove the PID registry file
try {
    if (Test-Path -LiteralPath $PidRegistry) {
        Remove-Item -LiteralPath $PidRegistry -Force -ErrorAction SilentlyContinue
    }
} catch {}

Write-Message -Level Info -Message "All done."
# endregion Main flow