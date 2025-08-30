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
  - Cleanup registry: a temporary PID registry file (.vlc_pids_<guid>.txt) is written in
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
(ProcessedLogPath) and the temporary PID registry (.vlc_pids_<guid>.txt).

.PARAMETER FramesPerSecond
Capture rate for screenshots per second. GDI+ mode uses exact time-based capture. 
VLC snapshot mode uses frame-count approximation based on detected video FPS 
(falls back to 30fps assumption if undetectable). Both modes maintain native playback speed.

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
"full-screen 1080p desktop grab" method. Ignored in VLC snapshot mode.

.PARAMETER ClearSnapshotsBeforeRun
When -UseVlcSnapshots is active, delete any existing snapshot files for the
current video's prefix (<VideoBaseName>_*.png) in SaveFolder before starting
VLC. Useful to avoid mixing frames across runs. Disabled by default.

.PARAMETER AutoStopGraceSeconds
Extra seconds added to detected video duration when auto-stopping VLC. Default 2.
This per-video upper bound is enforced regardless of whether a global limit is set.

.PARAMETER DisableAutoStop
Disable duration-based auto-stop; rely on VLC exit or -TimeLimitSeconds.

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

.INPUTS
None. You cannot pipe input to this script.

.OUTPUTS
None. Writes status/progress to the console and log files.

.NOTES
AUTHOR
  Manoj Bhaskaran

VERSION
  1.2.18

CHANGELOG
  1.2.18
  - Fix: Removed duplicate $vlcExit assignment to prevent logic drift and confusion
  - Fix: Unified frame count calculation in debug output to prevent uninitialized variable references in GDI+ mode
  - Fix: Added Wait-Process to Stop-Vlc function for consistent deterministic process termination across all code paths
  - Fix: Updated troubleshooting documentation to reflect actual GUID-based PID registry filenames (.vlc_pids_*.txt)
  - Fix: Corrected indentation inconsistencies in main capture try/catch/finally block

  1.2.17
  - Fix: Critical bug where GDI+ capture mode exit codes were uninitialized during outcome evaluation,
    causing successful captures to be incorrectly marked as failures
  - Fix: Moved VLC exit code evaluation to occur before outcome assessment for both capture modes
  - Fix: Removed duplicate troubleshooting documentation entry

  1.2.16
  - Fix: Removed duplicated exit code evaluation logic and consolidated into consistent approach across all capture modes
  - Fix: Added validation to FFprobe parsing to prevent exceptions on non-numeric results like "N/A"
  - Fix: Implemented proper COM object cleanup (Marshal.ReleaseComObject) in duration/FPS detection functions for better memory management
  - Fix: Use unique GUID-based PID registry filenames to prevent conflicts between concurrent script runs sharing SaveFolder
  - Fix: Added deterministic process termination with Wait-Process after Stop-Process -Force for reliable exit code reading
  - Improvement: Enhanced user feedback with specific timeout messages when videos aren't marked as processed
  - Improvement: Better resource management for long-running operations and concurrent usage scenarios

  1.2.15
  - Fix: Initialize timer variables ($startTime, $videoStartTime) used in debug logging to prevent runtime errors
  - Fix: Handle ExitCode unavailability after forced VLC process termination with proper wait and null checks  
  - Fix: Use invariant culture for number parsing to support international locales with comma decimal separators
  - Fix: Add ExtendedProperty fallback for Shell COM duration/FPS detection when localized headers fail
  - Fix: Support MM:SS duration format in addition to existing HH:MM:SS parsing
  - Fix: Convert processed video log from O(n) array lookup to O(1) HashSet for better performance with large collections
  - Cleanup: Remove unused $global:vlcPids variable and references
  - Improvement: Enhanced international compatibility and performance for large video sets

  1.2.14
  - Fix: Added process monitoring timeout for VLC snapshot mode to prevent indefinite hanging
  - Fix: VLC --stop-time parameter unreliable in snapshot mode, now using process termination fallback
  - Add: Configurable timeout based on detected video duration plus buffer (5 seconds) or 5-minute default
  - Add: Enhanced debug logging for VLC process monitoring and termination events
  - Improvement: More reliable snapshot mode operation that won't hang on problematic video files

  1.2.13
  - Fix: Corrected FFprobe command line argument handling (removed double-quoting issue)
  - Fix: Replaced Windows Shell COM ExtendedProperty method with GetDetailsOf method for better compatibility
    in both Get-VideoDurationSeconds and Get-VideoFps functions
  - Fix: Enhanced Shell COM duration parsing to handle time format strings (HH:MM:SS)
  - Fix: Enhanced frame rate parsing to handle multiple formats (decimal, "X fps", fractional notation)
  - Add: Debug logging for both duration and frame rate detection processes
  - Improvement: More robust duration detection and VLC snapshot cadence calculation across different 
    Windows versions and file formats

  1.2.12
  - Fix: Enhanced duration detection with multiple fallback methods for improved file compatibility
  - Add: FFprobe fallback for duration detection when Windows Shell COM properties unavailable  
  - Add: Multiple Windows metadata property attempts (System.Media.Duration, Duration, System.Video.Duration)
  - Improvement: More robust auto-stop functionality with better file format support

  1.2.11
  - Add: Comprehensive debug logging for duration detection, grace period calculation, and auto-stop logic
  - Add: Debug messages for VLC startup timing, early exit detection, and stop-time parameter configuration  
  - Add: Debug output for per-video deadline enforcement in GDI+ capture mode
  - Add: Video processing summary debug information showing exit codes, timing, and frame counts
  - Improvement: Enhanced diagnostic visibility for testing and troubleshooting auto-stop functionality

  1.2.10
  - Fix: Corrected Get-ChildItem calls using -LiteralPath with filters to use -Path instead,
    ensuring -Filter and -Include work reliably across PowerShell versions
  - Fix: Updated snapshot file cleanup, pre/post-count validation, and post-capture image 
    detection to use proper filter syntax for consistent operation

  1.2.9
  - Fix: Corrected FAQ documentation that incorrectly stated both capture modes use time-based cadence
    (VLC snapshot mode uses frame-ratio approximation due to VLC 3.x limitations)
  - Fix: Changed video file enumeration from -LiteralPath to -Path with wildcard to ensure -Include 
    filter works reliably across PowerShell versions

  1.2.8
  - Fix: VLC 3.0.21 compatibility - replaced unsupported --scene-fps with --scene-ratio calculation
    based on detected video frame rate for snapshot mode
  - Add: Get-VideoFps function to read video frame rate from file metadata for snapshot cadence calculation
  - Improvement: Snapshot mode now uses mathematical approximation (1 out of N frames) rather than
    time-based capture, with 30fps fallback for files without detectable frame rate

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
    runs producing blank screens when VLC doesn't exit cleanly.
    • Enabled by default when -TimeLimitSeconds is 0.
    • Disable with -DisableAutoStop.
    • Grace seconds controlled by -AutoStopGraceSeconds (default: 2).
  - Start-Vlc now passes --stop-time <seconds> when duration is known, and
    also adds --no-loop and --no-repeat for safety.
  - New parameters:
    • -AutoStopGraceSeconds <int>   # extra seconds beyond detected duration
    • -DisableAutoStop              # opt out of duration-based stop
  - Docs: added .PARAMETER entries for the two new flags and a
    TROUBLESHOOTING note about "screenshots continue after short clips".

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
  - Time-limit terminates VLC and prevents false "processed" logging.
  - Centralized cleanup: VLC closed/killed on all exit paths; non-zero VLC exit codes mark failure.
  - Add -PythonScriptPath; validate -ResumeFile in -CropOnly; startup timeout for VLC; optional snapshot mode.

  EXIT CODES
    0  Success
    1  Runtime error (processing/cropper failure, or log create/write failure)
    2  Usage/validation error (invalid paths, resume file not found, etc.)

  PREREQUISITES
  - VLC installed and in PATH (vlc.exe).
  - Python available if running the cropper; cropper script present.
  - FFprobe (optional) for enhanced duration detection on files with missing Windows metadata.

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
  - Stale .vlc_pids_*.txt files: If previous runs crashed, you may see PID registry files 
    in <SaveFolder>. These are safe to delete; each run creates a unique registry file.
  - Screenshots continue long after short clips: The script now enforces per-video timeouts in
    both capture modes. GDI+ mode uses deadline checking, snapshot mode uses process monitoring.
  - Very short clips exit during startup:
      • This is normal. From v1.2.2, a clean early exit (ExitCode=0) during the startup wait is
        treated as successful playbook completion, not a start failure.
  - VLC snapshot cadence not exact: VLC 3.x only supports frame-count ratios, not time-based FPS.
    The script calculates the closest ratio based on detected video frame rate. For exact 
    time-based capture, use GDI+ mode instead of -UseVlcSnapshots.
  - Duration detection fails: Install FFmpeg (includes FFprobe) for enhanced metadata reading.
    The script tries Windows Shell properties first, then falls back to FFprobe if available.
  - VLC hangs in snapshot mode: VLC's --stop-time parameter can be unreliable in headless mode.
    The script now monitors VLC processes and terminates them after video duration + 5 seconds
    (or 5 minutes maximum if duration unknown). Check debug output for timeout events.
  - International/locale issues: The script now supports international number formats (comma decimal separators)
    and attempts to detect localized property names. If duration/FPS detection still fails, ensure Windows
    file properties are populated correctly.
  - Performance with large video collections: Processed video tracking now uses HashSet for O(1) lookups
    instead of O(n) array searches, significantly improving performance with hundreds/thousands of videos.
  - Concurrent script runs: Multiple script instances can now safely share the same SaveFolder. 
    Each run uses a unique PID registry file (.vlc_pids_<guid>.txt) to avoid VLC process conflicts.
  - Memory usage with many videos: COM object cleanup is now properly implemented to prevent 
    memory accumulation during large batch processing operations.

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

  Q: What's the difference between GDI+ and snapshot mode?
  A: GDI+ captures the desktop (quick to set up; may include UI). Snapshot mode uses VLC's scene filter to save only the video content (no UI), typically cleaner for analysis.

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
  A: No. GDI+ mode uses exact time-based capture; VLC snapshot mode uses frame-ratio 
     approximation based on detected video FPS due to VLC 3.x limitations. Both maintain 
     native playbook speed, but only GDI+ provides precise timing.

  Q: Why don't I get exactly N screenshots per second in snapshot mode?
  A: VLC 3.x uses frame-count ratios (save 1 out of every N frames) rather than time-based capture.
     The script calculates the best approximation based on video FPS. GDI+ mode provides exact timing.

  Q: Why does VLC get forcibly terminated in snapshot mode?
  A: VLC's --stop-time parameter doesn't work reliably in headless snapshot mode. The script
      monitors the process and terminates it after the expected duration plus a 5-second buffer
      to prevent indefinite hanging while ensuring complete frame capture.
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
    [int]$AutoStopGraceSeconds = 2,

    [Parameter(Mandatory = $false)]
    [switch]$DisableAutoStop
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
            Start-Sleep -Milliseconds (200 * $i)
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
    $ProcessedLogPath = Join-Path $SaveFolder 'processed_videos.log'
} elseif (-not [System.IO.Path]::IsPathRooted($ProcessedLogPath)) {
    $ProcessedLogPath = Join-Path $SaveFolder $ProcessedLogPath
}

# Ensure the log directory exists, create the file if missing, and verify writability
try {
    $logDir = Split-Path -Parent $ProcessedLogPath
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
    }
    if (-not (Test-Path -LiteralPath $ProcessedLogPath)) {
        New-Item -ItemType File -Path $ProcessedLogPath -Force -ErrorAction Stop | Out-Null
    }
    $fs = [System.IO.File]::Open(
        $ProcessedLogPath,
        [System.IO.FileMode]::Append,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::Read
    )
    $fs.Close()
} catch {
    Write-Message -Level Error -Message "Processed log must be creatable and writable: $ProcessedLogPath – $($_.Exception.Message)"
    exit 1
}

# PID registry used by event handlers - unique per run to avoid concurrent conflicts
$RunGuid = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
$PidRegistry = Join-Path $SaveFolder ".vlc_pids_$RunGuid.txt"
Write-Debug "Using PID registry: $PidRegistry"
if (Test-Path -LiteralPath $PidRegistry) {
    Remove-Item -LiteralPath $PidRegistry -Force -ErrorAction SilentlyContinue
}

if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' }

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
Get video duration using Windows Shell COM GetDetailsOf method.

.DESCRIPTION
Searches through Windows Shell property columns to find duration information.
Parses various time formats including HH:MM:SS strings. This method works
better than ExtendedProperty on some Windows versions and file types.

.PARAMETER Path
Full path to the video file.
#>
function Get-VideoDurationViaShell {
    param([Parameter(Mandatory)][string]$Path)
    $shell = $null
    $folder = $null
    $item = $null
    try {
        $shell  = New-Object -ComObject Shell.Application
        $folder = $shell.NameSpace((Split-Path -LiteralPath $Path))
        $item   = $folder.ParseName((Split-Path -Leaf -LiteralPath $Path))
        
        # Method 1: GetDetailsOf scan (works with localized headers)
        for ($i = 0; $i -lt 300; $i++) {
            $header = $folder.GetDetailsOf($null, $i)
            if ($header -match "Length|Duration|Durée|Dauer|Duración") {
                $v = $folder.GetDetailsOf($item, $i)
                if ($v -and $v.Trim()) {
                    Write-Debug "Duration from Shell COM column $i ($header): $v"
                    if ($v -match "(\d{1,2}):(\d{2}):(\d{2})") {
                        $hours = [int]$matches[1]
                        $minutes = [int]$matches[2] 
                        $seconds = [int]$matches[3]
                        return ($hours * 3600) + ($minutes * 60) + $seconds
                    }
                    if ($v -match "(\d{1,2}):(\d{2})") {
                        $minutes = [int]$matches[1]
                        $seconds = [int]$matches[2]
                        return ($minutes * 60) + $seconds
                    }
                }
            }
        }
        
        # Method 2: ExtendedProperty fallback with canonical names
        $canonicalProps = @('System.Media.Duration', 'Duration')
        foreach ($prop in $canonicalProps) {
            try {
                $v = $item.ExtendedProperty($prop)
                if ($v) {
                    Write-Debug "Duration from ExtendedProperty $prop`: $v"
                    if ($v -is [string] -and $v.Trim()) { return [TimeSpan]::Parse($v).TotalSeconds }
                    if ($v -is [long] -or $v -is [int]) { return [double]$v / 10000000.0 }
                }
            } catch {
                Write-Debug "ExtendedProperty $prop failed: $($_.Exception.Message)"
            }
        }
        
        Write-Debug "No duration properties found via Shell COM"
        return $null
    } catch {
        Write-Debug "Shell COM duration detection failed: $($_.Exception.Message)"
        return $null
    } finally {
        if ($item)   { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($item) } catch {} }
        if ($folder) { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($folder) } catch {} }
        if ($shell)  { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } catch {} }
    }
}

<#
.SYNOPSIS
Get video duration using FFprobe command line tool.

.DESCRIPTION
Uses FFprobe (part of FFmpeg) to extract duration metadata directly from
the video file. Requires FFprobe to be installed and available in PATH.
Provides reliable duration detection for files with non-standard metadata.

.PARAMETER Path
Full path to the video file.
#>
function Get-VideoDurationViaFFprobe {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
        if (-not $ffprobe) {
            Write-Debug "FFprobe not found in PATH"
            return $null
        }
        
        Write-Debug "Trying FFprobe for duration detection"
        $result = & ffprobe -v quiet -show_entries format=duration -of csv=p=0 $Path 2>$null
        if ($result -and $result.ToString().Trim()) {
            $resultStr = $result.ToString().Trim()
            # Validate before parsing to avoid exceptions on "N/A" or error strings
            if ($resultStr -match '^\d+\.?\d*$') {
                $duration = [double]::Parse($resultStr, [System.Globalization.CultureInfo]::InvariantCulture)
                Write-Debug "Duration from FFprobe: $duration sec"
                return $duration
            } else {
                Write-Debug "FFprobe returned non-numeric result: $resultStr"
            }
        }
        
        Write-Debug "FFprobe returned no duration data"
        return $null
    } catch {
        Write-Debug "FFprobe duration detection failed: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Return video duration in seconds using multiple detection methods.

.DESCRIPTION
Attempts to detect video duration using Windows Shell COM properties first,
then falls back to FFprobe if available. Supports various metadata formats
and time string parsing for maximum file compatibility.

.PARAMETER Path
Full path to the video file.

.EXAMPLE
$duration = Get-VideoDurationSeconds -Path 'C:\video.mp4'
#>
function Get-VideoDurationSeconds {
    param([Parameter(Mandatory)][string]$Path)
    
    # Method 1: Enhanced Shell COM with multiple properties
    $duration = Get-VideoDurationViaShell -Path $Path
    if ($duration) { return $duration }
    
    # Method 2: FFprobe fallback
    $duration = Get-VideoDurationViaFFprobe -Path $Path  
    if ($duration) { return $duration }
    
    Write-Debug "All duration detection methods failed for: $Path"
    return $null
}

<#
.SYNOPSIS
Get video frame rate using Windows Shell COM GetDetailsOf method.

.DESCRIPTION
Searches through Windows Shell property columns to find frame rate information.
Handles various frame rate formats including decimal values, "X fps" strings,
and fractional notation (e.g., "30000/1001"). Uses the same GetDetailsOf 
approach as duration detection for better Windows version compatibility.

.PARAMETER Path
Full path to the video file.

.EXAMPLE
$fps = Get-VideoFps -Path 'C:\video.mp4'
if ($fps) { Write-Host "Video runs at $fps FPS" }

.NOTES
This function is used internally by VLC snapshot mode to calculate the 
appropriate --scene-ratio parameter for time-based frame capture approximation.
Falls back to 30 FPS assumption if detection fails.
#>
function Get-VideoFps {
    param([Parameter(Mandatory)][string]$Path)
    $shell = $null
    $folder = $null
    $item = $null
    try {
        $shell  = New-Object -ComObject Shell.Application
        $folder = $shell.NameSpace((Split-Path -LiteralPath $Path))
        $item   = $folder.ParseName((Split-Path -Leaf -LiteralPath $Path))
        
        # Method 1: GetDetailsOf scan (works with localized headers)
        for ($i = 0; $i -lt 300; $i++) {
            $header = $folder.GetDetailsOf($null, $i)
            if ($header -match "Frame rate|FPS|Video frame rate|Fréquence d'images|Bildrate") {
                $v = $folder.GetDetailsOf($item, $i)
                if ($v -and $v.Trim()) {
                    Write-Debug "Frame rate from Shell COM column $i ($header): $v"
                    
                    if ($v -match "(\d+\.?\d*)\s*fps") {
                        $fps = [double]::Parse($matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
                        if ($fps -gt 0) { return $fps }
                    }
                    if ($v -match "^(\d+\.?\d*)$") {
                        $fps = [double]::Parse($matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
                        if ($fps -gt 0) { return $fps }
                    }
                    if ($v -match "(\d+)/(\d+)") {
                        $numerator = [double]$matches[1]
                        $denominator = [double]$matches[2]
                        if ($denominator -gt 0) {
                            $fps = $numerator / $denominator
                            if ($fps -gt 0) { return $fps }
                        }
                    }
                }
            }
        }
        
        # Method 2: ExtendedProperty fallback with canonical names
        $canonicalProps = @('System.Video.FrameRate')
        foreach ($prop in $canonicalProps) {
            try {
                $v = $item.ExtendedProperty($prop)
                if ($v) {
                    Write-Debug "Frame rate from ExtendedProperty $prop`: $v"
                    if ($v -is [long] -or $v -is [int]) { 
                        $fps = [double]$v / 1000.0
                        if ($fps -gt 0) { return $fps }
                    }
                }
            } catch {
                Write-Debug "ExtendedProperty $prop failed: $($_.Exception.Message)"
            }
        }
        
        Write-Debug "No frame rate properties found via Shell COM"
        return $null
    } catch {
        Write-Debug "Shell COM frame rate detection failed: $($_.Exception.Message)"
        return $null
    } finally {
        if ($item)   { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($item) } catch {} }
        if ($folder) { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($folder) } catch {} }
        if ($shell)  { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } catch {} }
    }
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
Destination for snapshot files when -UseVlcSnapshots is enabled.

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

    $common = @(
        '--no-qt-privacy-ask',
        '--no-video-title-show',
        '--no-loop',
        '--no-repeat',
        '--rate', '1',
        '--play-and-exit'
    )

    $vlcargs = @("`"$VideoPath`"")

    if ($StopAtSeconds -gt 0) {
        $roundedStop = [int][Math]::Round($StopAtSeconds)
        $vlcargs += @('--stop-time', [string]$roundedStop)
        Write-Debug "VLC will be configured with --stop-time=$roundedStop (from stopAt=$StopAtSeconds)"
    } else {
        Write-Debug "No --stop-time parameter (stopAt=$StopAtSeconds)"
    }

    if ($UseVlcSnapshots) {
        $vlcargs += @(
            '--intf', 'dummy',
            '--video-filter=scene',
            "--scene-path=""$SaveFolder""",
            "--scene-prefix=""$([IO.Path]::GetFileNameWithoutExtension($VideoPath))_""",
            '--scene-format=png'
        )
        $vfps  = Get-VideoFps -Path $VideoPath
        $base  = if ($vfps -and $vfps -gt 0) { [double]$vfps } else { 30.0 }
        $ratio = [int][Math]::Max(1, [Math]::Round($base / [double]$FramesPerSecond))
        $vlcargs += @("--scene-ratio=$ratio")
        Write-Debug "Snapshots (VLC 3.x): video_fps=$base; requested=$FramesPerSecond; using --scene-ratio=$ratio"
    } else {
        if ($GdiFullscreen) {
            $vlcargs += @('--fullscreen', '--video-on-top', '--qt-minimal-view')
        }
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
    $startTime = Get-Date
    $null = $p.Start()
    Add-Content -LiteralPath $PidRegistry -Value $p.Id

    $deadline = (Get-Date).AddSeconds($VlcStartupTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($p.HasExited) { break }
        Start-Sleep -Milliseconds 200
    }

    if ($p.HasExited) {
        $stderr = $p.StandardError.ReadToEnd()
        $exitTime = (Get-Date) - $startTime
        if ($p.ExitCode -eq 0) {
            Write-Debug "VLC exited cleanly during startup window (short clip). ExitCode=0, elapsed=$($exitTime.TotalSeconds) sec"
            return $p
        }
        Write-Debug "VLC failed during startup. ExitCode=$($p.ExitCode), elapsed=$($exitTime.TotalSeconds) sec"
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
    param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)
    try   { $null = $Process.CloseMainWindow() } catch {}
    try   { $Process.WaitForExit(5000) } catch {}
    if (-not $Process.HasExited) {
        Write-Debug "VLC still running; force killing PID $($Process.Id)"
        try { 
            Stop-Process -Id $Process.Id -Force 
            # Wait for process to actually terminate for consistent behavior
            Wait-Process -Id $Process.Id -Timeout 3000 -ErrorAction SilentlyContinue
            $Process.Refresh()
        } catch {
            Write-Debug "Error during VLC termination: $($_.Exception.Message)"
        }
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
    param(
        [Parameter(Mandatory)][string]$PythonScriptPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [string]$ResumeFile
    )

    $pv = (& python --version) 2>&1
    if ($pv -notmatch '^Python 3\.(9|[1-9][0-9])\.') {
        throw "Python 3.9+ required (found: $pv)"
    }

    if (-not (Test-Path -LiteralPath $PythonScriptPath)) {
        throw "PythonScriptPath not found: $PythonScriptPath"
    }

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
        $resumeArg = @('--resume-file', "`"$resumePath`"")
    }

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
$videos = Get-ChildItem -Path (Join-Path $SourceFolder '*') -Recurse -File -Include $videoExt | Sort-Object FullName

if ($VideoLimit -gt 0) {
    $videos = $videos | Select-Object -First $VideoLimit
}

# Use HashSet for O(1) processed video lookups
$processed = New-Object System.Collections.Generic.HashSet[string]
try {
    $processedArray = Get-Content -LiteralPath $ProcessedLogPath -ErrorAction Stop
    foreach ($item in $processedArray) {
        [void]$processed.Add($item)
    }
    Write-Debug "Loaded $($processed.Count) processed videos into HashSet"
} catch {
    Write-Message -Level Error -Message "Failed to read processed log: $ProcessedLogPath – $($_.Exception.Message)"
    exit 1
}

$intervalMs = [int](1000 / [Math]::Max(1, $FramesPerSecond))

$globalStart = Get-Date
foreach ($video in $videos) {
    if ($TimeLimitSeconds -gt 0 -and ((New-TimeSpan -Start $globalStart -End (Get-Date)).TotalSeconds -ge $TimeLimitSeconds)) {
        Write-Message -Level Info -Message "Global time limit of $TimeLimitSeconds seconds reached; stopping processing."
        break
    }
    $already = $processed.Contains($video.FullName)
    if ($already) {
        Write-Message -Level Info -Message "Skipping (already processed): $($video.FullName)"
        continue
    }

    Write-Message -Level Info -Message "Processing: $($video.FullName)"
    $videoStartTime = Get-Date
    $vlc = $null
    $errorDuringCapture = $false
    $savedThisRun = 0
    $hadFrames = $false
    $preCount = 0
    $scenePrefixForThisVideo = ([IO.Path]::GetFileNameWithoutExtension($video.FullName)) + '_'

    if ($UseVlcSnapshots) {
        if ($ClearSnapshotsBeforeRun) {
            Get-ChildItem -Path $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            $preCount = 0
        } else {
            $preCount = (Get-ChildItem -Path $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        }
    }

    try {
        $stopAt = 0
        if (-not $DisableAutoStop) {
            $dur = Get-VideoDurationSeconds -Path $video.FullName
            if ($dur -and $dur -gt 0) { 
                $stopAt = [double]$dur + [double]$AutoStopGraceSeconds 
                Write-Debug "Duration detection: raw=$dur sec, grace=$AutoStopGraceSeconds sec, stopAt=$stopAt sec"
            } else {
                Write-Debug "Duration detection: unable to detect duration, no auto-stop will be applied"
            }
        } else {
            Write-Debug "Auto-stop disabled via -DisableAutoStop parameter"
        }
        
        $vlc = Start-Vlc -VideoPath $video.FullName -SaveFolder $SaveFolder `
                    -UseVlcSnapshots:$UseVlcSnapshots -StopAtSeconds:$stopAt

        if (-not $vlc) {
            throw "Failed to start VLC for: $($video.FullName)"
        }

        if ($UseVlcSnapshots) {
            $processStart = Get-Date
            $maxWait = if ($stopAt -gt 0) { $stopAt + 5 } else { 300 }
            Write-Debug "Snapshot mode: monitoring VLC process (max wait: $maxWait sec)"
            
            while (-not $vlc.HasExited) {
                Start-Sleep -Milliseconds 200
                $elapsed = (New-TimeSpan -Start $processStart -End (Get-Date)).TotalSeconds
                if ($elapsed -ge $maxWait) {
                    Write-Debug "VLC process timeout reached ($elapsed sec), force terminating"
                    Write-Message -Level Warn -Message "VLC timeout reached after $([int]$elapsed)s, terminating process for: $($video.FullName)"
                    try {
                        Stop-Process -Id $vlc.Id -Force -ErrorAction SilentlyContinue
                        # Wait for process to actually terminate
                        Wait-Process -Id $vlc.Id -Timeout 3000 -ErrorAction SilentlyContinue
                        $vlc.Refresh()
                        Write-Debug "Process termination completed"
                    } catch {
                        Write-Debug "Error during process termination: $($_.Exception.Message)"
                    }
                    break
                }
            }
            
            $finalElapsed = (New-TimeSpan -Start $processStart -End (Get-Date)).TotalSeconds
            Write-Debug "VLC process completed after $finalElapsed seconds"
        } else {
            $frameIndex = 0
            $videoBase  = [IO.Path]::GetFileNameWithoutExtension($video.Name)
            
            $perVideoDeadline = if ($stopAt -gt 0) { (Get-Date).AddSeconds($stopAt) } else { $null }
            if ($perVideoDeadline) {
                Write-Debug "GDI+ capture: per-video deadline set to $($perVideoDeadline.ToString('HH:mm:ss'))"
            } else {
                Write-Debug "GDI+ capture: no per-video deadline (unlimited capture)"
            }

            while (-not $vlc.HasExited) {
                if ($perVideoDeadline -and (Get-Date) -ge $perVideoDeadline) {
                    $elapsed = (New-TimeSpan -Start $videoStartTime -End (Get-Date)).TotalSeconds
                    Write-Debug "Per-video deadline reached after $elapsed seconds of capture"
                    Write-Message -Level Info -Message "Per-video time limit reached for: $($video.FullName)"
                    break
                }
                
                $filename = ('{0}_{1:D6}.png' -f $videoBase, $frameIndex)
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

    # Evaluate VLC exit code consistently for both capture modes
    $vlcExit = if ($vlc -and -not $vlc.HasExited) { 
        -1  # Still running 
    } elseif ($vlc -and $null -ne $vlc.ExitCode) { 
        $vlc.ExitCode 
    } else { 
        -1  # ExitCode not available
    }

    # Post-run validation: ensure frames actually exist
    if ($UseVlcSnapshots) {
        $postCount = (Get-ChildItem -Path $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $hadFrames = ($postCount -gt $preCount)
        $framesDelta = $postCount - $preCount
    } else {
        $hadFrames = ($savedThisRun -gt 0)
        $framesDelta = $savedThisRun
    }

    # Unified debug output that works for both modes
    $processingTime = if ($videoStartTime) { (New-TimeSpan -Start $videoStartTime -End (Get-Date)).TotalSeconds } else { 0 }
    Write-Debug "Video processing complete: ExitCode=$vlcExit, processingTime=$processingTime sec, frames=$framesDelta, hadErrors=$errorDuringCapture"

    # Final outcome evaluation
    $ok = (-not $errorDuringCapture) -and ($vlcExit -eq 0) -and $hadFrames

    if ($ok) {
        if (Add-ContentWithRetry -Path $ProcessedLogPath -Value $video.FullName) {
            Write-Message -Level Info -Message "Marked processed: $($video.FullName)"
        } else {
            Write-Message -Level Error -Message "Processed OK, but failed to update processed log: $ProcessedLogPath"
            exit 1
        }
    } else {
        # Provide specific feedback for timeout cases
        if ($UseVlcSnapshots -and $vlcExit -ne 0 -and -not $hadFrames) {
            Write-Message -Level Warn -Message "Video timed out after $([int]$finalElapsed)s; not marking as processed: $($video.FullName)"
        } elseif (-not $hadFrames) {
            Write-Message -Level Warn -Message "No frames captured; not marking as processed: $($video.FullName)"
        } else {
            Write-Debug "Video not marked processed - VlcExit: $vlcExit, HadFrames: $hadFrames, Errors: $errorDuringCapture"
        }
    }
}

# Post-capture cropper
try {
    if (Get-ChildItem -Path (Join-Path $SaveFolder '*') -Recurse -File -Include *.png,*.jpg,*.jpeg -ErrorAction SilentlyContinue | Select-Object -First 1) {
        Write-Message -Level Info -Message "Invoking crop_colours.py on $SaveFolder (post-capture)."
        Invoke-Cropper -PythonScriptPath $PythonScriptPath -SaveFolder $SaveFolder -ResumeFile $ResumeFile
    } else {
        Write-Message -Level Info -Message "No images found in $SaveFolder for cropping; skipping."
    }
} catch {
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