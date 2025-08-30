<#
.SYNOPSIS
Captures video frames from VLC or the desktop and (optionally) runs a Python cropper.

.DESCRIPTION
Plays each video file via VLC and saves periodic screenshots to a target folder.
Two capture approaches are supported (choose based on your goal):

  1) Desktop capture via GDI+ (default)
     • Captures the primary screen at native resolution and timing (exact time-based cadence).
     • Easiest to set up; no VLC filters required.
     • May include UI “chrome” (menus/title bars). Use -GdiFullscreen to minimize this.
     • Image size matches your desktop; can be very large on high-DPI/4K displays.

  2) VLC scene snapshots (opt-in via -UseVlcSnapshots)
     • Headless video-frame-only capture (no desktop/UI).
     • Cadence is frame-ratio based (VLC 3.x limitation): saves 1 out of N frames derived from video FPS.
       Exact N FPS is not guaranteed; for precise timing use GDI+.
     • Falls back to 30 FPS when video FPS is undetectable (documented limitation).

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
one level above this script folder (..\python\crop_colours.py), i.e., a sibling to the 'powershell' folder.

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
   1.2.33

CHANGELOG
  1.2.33
  - Fix: Shell COM frame rate detection no longer hits a Split-Path parameter-set conflict. Replaced Split-Path with .NET path helpers; added null checks and defensive COM cleanup, with clearer debug traces.
  - UX: Print a one-time startup banner that includes the script version (e.g., “videoscreenshot.ps1 v1.2.33 starting…”).

    1.2.32
  - Fix: Shell COM duration detection no longer trips a Split-Path parameter-set conflict. Replaced Split-Path usage with .NET path helpers (GetFullPath / GetDirectoryName / GetFileName).
  - Hardening: Added early null/invalid-path checks and graceful $null returns when the folder or item cannot be resolved.
  - Parsing: Expanded support for duration formats (HH:MM:SS(.ms), MM:SS(.ms), HH:MM:SS;ff) and kept canonical ExtendedProperty fallbacks (System.Media.Duration / Duration).
  - Reliability: Defensive COM cleanup (ReleaseComObject) for item/folder/shell to reduce resource leaks.
  - Observability: Richer Write-Debug traces for each detection path and failure reason.
  - No public parameter changes; behavior is identical on success—only improved robustness on edge cases.

  1.2.31
   - Bug fix: Clean up event handlers and jobs on script start
  1.2.30
  - Bug fix: Fixed Python module detection by explicitly importing importlib.util submodule.
    The previous code imported importlib but tried to access importlib.util without explicitly
    importing the submodule, causing AttributeError on module detection checks.
  1.2.29
  - Robustness: Improved Python version detection to handle non-English locales by parsing
    version components systematically instead of using locale-dependent regex patterns.
  - Security: Replaced string-based argument concatenation with array-based arguments in 
    Invoke-Python and Invoke-Cropper to prevent potential argument injection.
  1.2.28
  - Logging: Removed duplicate INFO messages. Write-Message (Info) now routes to a single native
    stream: Write-Information when available, with a Host fallback only if Information isn’t supported.
    This prevents “double print” scenarios while preserving structured logging behavior controlled by
    $InformationPreference / -InformationAction.
  - Cropper preflight: Verify required Python modules (numpy, cv2) in the active interpreter before
    running the cropper. If missing, the script bootstraps pip via `python -m ensurepip` (when needed)
    and attempts `python -m pip install numpy opencv-python`. If installation still fails (offline /
    restricted env), the run terminates with an actionable error (exit 1).
  - Docs: PREREQUISITES/TROUBLESHOOTING updated to document the auto-install behavior, how to preinstall
    manually, and common failure modes (no network, blocked index, policy restrictions)

   1.2.27
   - Snapshot mode UX: add a pre-run warning when -FramesPerSecond exceeds detected video FPS; cadence will be limited to 1:1 (frame-per-frame).
   - Validation: add stricter parameter validation to several helpers (paths non-empty; positive ranges; width/height pairing).
   - Errors: make key errors more actionable (suggest next steps for SourceFolder/VLC missing; “no frames” guidance).
   - Complexity: moved common helpers (Measure-PostCapture, Assert-FolderWritable) into the optional util module; script keeps fallbacks when module is absent.
   - Docs: trimmed historical patch-level CHANGELOG noise; most recent five patch versions remain detailed, older entries are condensed.

   1.2.26
   - Import UX: Debug-only note when optional module is not found; richer warning when present but fails to import.
   - Docs: TROUBLESHOOTING notes for optional module placement/unblock/execution policy.

   1.2.1-1.2.25 (condensed):
  - Robustness: Safer process termination, improved metadata detection (Shell/FFprobe), cross-locale 
    parsing, O(1) processed lookups, enhanced import handling with graceful fallback for optional modules.
  - UX/Observability: Clearer warnings for snapshot cadence/FFprobe absence, detailed Debug traces 
    for timings and FPS, snapshot-mode FPS deviation warnings, enriched import failure guidance.
  - Architecture: Split capture helpers into focused functions, introduced Initialize-VideoContext 
    for per-video state management, optional util module pattern with better troubleshooting docs.
  - Behavior: Reliable per-video/global timeouts, GDI monotonic scheduling, snapshot process monitoring,
    improved Write-Message stream routing to native PowerShell streams.
  - Fixes: Argument quoting, filter usage, exit-code handling, PID registry naming, duplicate logic 
    removal, and other quality-of-life improvements across 25 patch releases.
  - Refer to commit history for full details.

  1.2.0
  - Default processed log now resolves under <SaveFolder> as processed_videos.log when -ProcessedLogPath
    is omitted. Bare filenames/relative paths resolve under <SaveFolder>.
  - Log create/append failures are terminating errors (exit 1).
  - PID-registry: write <SaveFolder>\.vlc_pids.txt; Ctrl+C and PowerShell.Exiting handlers terminate
    only PIDs launched by this run; entries are removed after Stop-Vlc.
  - Start-Vlc: write PID to registry; surface VLC stderr on failed start (shown with -Debug).

  1.1.x (1.1.1–1.1.12)
  - Summary: Quality-of-life fixes and robustness for the 1.1 line, including:
    • Per-video scene prefix and post-run validation; retries for GDI+ saves and cropper.
    • Process/PID tracking with reliable cleanup on Ctrl+C and session exit.
    • GDI+ quality switches (-GdiFullscreen, -Legacy1080p) and snapshot housekeeping.
    • Cropper integration, Python 3.9+ enforcement, safer logging/argument fixes.
    See commits between 1.1.0..1.2.0 for full details.

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
  - FFprobe (optional but recommended) in PATH for robust duration detection.
    Download via FFmpeg and ensure `ffprobe` is available in your shell.
  - Optional module: videoscreenshot.util.psm1 (same folder as this script).
    Provides Write-Message and Add-ContentWithRetry. If present, the script imports it.
    If missing or it fails to load, the script falls back to built-in helpers and
    prints a warning for visibility.

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
      treated as successful playback completion, not a start failure.
  - VLC snapshot cadence not exact: VLC 3.x only supports frame-count ratios, not time-based FPS.
    The script calculates the closest ratio based on detected video frame rate. For exact 
    time-based capture, use GDI+ mode instead of -UseVlcSnapshots.
  - Runtime warnings:
    • When -UseVlcSnapshots is active, a one-time warning explains frame-ratio cadence and
      recommends GDI+ for precise timing.
    • When FFprobe is not found in PATH, a one-time warning explains that duration detection
      falls back to Windows file metadata and auto-stop may be less reliable.
    • When the optional helper module (videoscreenshot.util.psm1) is present but fails to import,
      a warning is printed and the script uses built-in fallbacks for logging and safe file appends.
  - Optional helper module not found:
    • The script will use built-in helpers (this is normal if you didn’t add the module).
    • To enable the module, place 'videoscreenshot.util.psm1' in the same folder as this script ($PSScriptRoot).
    • If downloaded from the internet, run: Unblock-File -Path .\videoscreenshot.util.psm1
    • Ensure execution policy allows module import (e.g., RemoteSigned). Details are emitted to the Debug stream.
  - Duration detection fails: Install FFmpeg (includes FFprobe) for enhanced metadata reading.
    The script tries Windows Shell properties first, then falls back to FFprobe if available.
  - Cropper prerequisites (numpy / OpenCV):
      • The script verifies `numpy` and `cv2` before running the cropper and will attempt to install them
        into the active Python interpreter (`python -m pip install numpy opencv-python`).
      • If `pip` is missing, the script tries `python -m ensurepip` first.
      • If installation fails (offline network, blocked index, or restricted env), the run terminates with a clear error.
        You can preinstall manually in the same interpreter with:
          python -m pip install numpy opencv-python
  - VLC hangs in snapshot mode: VLC's --stop-time parameter can be unreliable in headless mode.
    The script now monitors VLC processes and terminates them after video duration + 5 seconds
    (or 5 minutes maximum if duration unknown). Check debug output for timeout events.
  - Per-video timeout semantics (snapshot mode):
    • If the snapshot watchdog reaches the per-video limit derived from detected duration + AutoStopGraceSeconds,
      the video is treated as processed even if VLC had to be force-terminated and zero frames were saved.
      This prevents the same clip from being retried indefinitely.
    • If duration is unknown (300s fallback timeout), the video is NOT marked processed.
    • Tune AutoStopGraceSeconds if you find legitimate videos being cut a bit early.
  - International/locale issues: The script now supports international number formats (comma decimal separators)
    and attempts to detect localized property names. If duration/FPS detection still fails, ensure Windows
    file properties are populated correctly.
  - Performance with large video collections: Processed video tracking now uses HashSet for O(1) lookups
    instead of O(n) array searches, significantly improving performance with hundreds/thousands of videos.
  - Concurrent script runs: Multiple script instances can now safely share the same SaveFolder. 
    Each run uses a unique PID registry file (.vlc_pids_<guid>.txt) to avoid VLC process conflicts.
  - Memory usage with many videos: COM object cleanup is now properly implemented to prevent 
    memory accumulation during large batch processing operations.
  - Users may see the following runtime warnings/messages during execution:
      • "Snapshot mode uses frame-count ratio..." when -UseVlcSnapshots is set (reminder that cadence is ratio-based).
      • "FFprobe not found in PATH..." when ffprobe is missing (duration detection fallback; auto-stop may be less reliable).
      • "Snapshot cadence deviates by NN%..." if achieved FPS differs ≥20% from requested (helps non-debug users spot inaccuracies).
  - Example (frame-ratio impact):
      • Requested 5 FPS on a 24 FPS source → best 1/N ratio ≈ 1/5 → ~4.8 FPS.
      • 50-second clip → expected frames at 5 FPS = 250; actual ≈ 240. This is normal for snapshot mode.
      • For exact time-based cadence, use GDI+ instead of -UseVlcSnapshots.

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
     native playback speed, but only GDI+ provides precise timing.

  Q: Why don't I get exactly N screenshots per second in snapshot mode?
  A: VLC 3.x uses frame-count ratios (save 1 out of every N frames) rather than time-based capture.
     The script calculates the best approximation based on video FPS. GDI+ mode provides exact timing.

  Q: Why does VLC get forcibly terminated in snapshot mode?
  A: VLC's --stop-time parameter doesn't work reliably in headless snapshot mode. The script
      monitors the process and terminates it after the expected duration plus a 5-second buffer
      to prevent indefinite hanging while ensuring complete frame capture.

  Q: Why was a timed-out video marked as processed?
  A: In snapshot mode, when the watchdog hits the expected per-video bound (detected duration + grace),
     the script intentionally marks the video as processed to avoid repeated loops on uncooperative files.

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
    [ValidateNotNullOrEmpty()]
    [string]$PythonScriptPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'python\crop_colours.py'),

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

# Script version constant for banner/logging
$script:VideoScreenshotVersion = '1.2.33'

# region Utilities

# Try optional helper module; define fallbacks if missing so the script stays self-contained
$utilModulePath = Join-Path $PSScriptRoot 'videoscreenshot.util.psm1'
if (Test-Path -LiteralPath $utilModulePath) {
    try {
        Import-Module -Name $utilModulePath -Force -ErrorAction Stop | Out-Null
    } catch {
        # User-visible guidance + mirrored debug for diagnostics
        Write-Warning -Message ("Optional utilities module failed to load: {0}. " +
                                "Ensure 'videoscreenshot.util.psm1' is in the same folder as this script ({1}), " +
                                "check permissions/execution policy (try Unblock-File on the module and/or Set-ExecutionPolicy RemoteSigned), " +
                                "then retry. Falling back to built-in helpers.") -f $utilModulePath, $PSScriptRoot
        Write-Debug ("Util module import failed: {0}" -f $_.Exception.Message)
    }
} else {
    Write-Debug ("Optional utilities module not found at {0}. Using built-in helpers. " +
                 "To enable it, place 'videoscreenshot.util.psm1' next to this script ({1}) and ensure it can be imported.") -f $utilModulePath, $PSScriptRoot
}

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
if (-not (Get-Command Add-ContentWithRetry -ErrorAction SilentlyContinue)) {
    function Add-ContentWithRetry {
        param(
            [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
            [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Value,
            [ValidateRange(1,10)][int]$MaxAttempts = 3
        )
        for ($i=1; $i -le $MaxAttempts; $i++) {
            try {
                $newline = [Environment]::NewLine
                $bytes   = [System.Text.Encoding]::UTF8.GetBytes($Value + $newline)
                $fs = [System.IO.File]::Open($Path,
                    [System.IO.FileMode]::Append,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None) # exclusive append to avoid interleaving
                $fs.Write($bytes, 0, $bytes.Length)
                $fs.Close()
                return $true
            } catch {
                if ($i -eq $MaxAttempts) {
                    Write-Message -Level Error -Message "Failed to append to ${Path}: $($_.Exception.Message)"
                    return $false
                }
                Start-Sleep -Milliseconds (200 * $i) # linear backoff
            }
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
if (-not (Get-Command Write-Message -ErrorAction SilentlyContinue)) {
    function Write-Message {
        param(
            [ValidateSet('Info','Warn','Error')]
            [string]$Level = 'Info',
            [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message
        )
        $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $formatted = "[$ts] [$($Level.ToUpper().PadRight(5))] $Message"
        switch ($Level) {
            'Info'  { try { Write-Information -MessageData $formatted -InformationAction Continue } catch { Write-Host $formatted } }
            'Warn'  { Write-Warning -Message $formatted; Write-Debug $formatted }
            'Error' { Write-Error   -Message $formatted; Write-Debug $formatted }
        }
    }
}

# --- Startup banner (after Write-Message exists) ---
try {
    $mode = if ($UseVlcSnapshots) { 'VLC snapshots' } else { 'GDI+ desktop' }
    Write-Message -Level Info -Message ("videoscreenshot.ps1 v{0} starting (Mode={1}, FPS={2}, SaveFolder=""{3}"")" -f $script:VideoScreenshotVersion, $mode, $FramesPerSecond, $SaveFolder)
} catch { }

# Generic: assert a folder is writable (moved to util module; keep fallback here)
if (-not (Get-Command Assert-FolderWritable -ErrorAction SilentlyContinue)) {
    function Assert-FolderWritable {
        param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Folder)
        try {
            if (-not (Test-Path -LiteralPath $Folder)) {
                New-Item -ItemType Directory -Path $Folder -Force | Out-Null
            }
            $tmp = Join-Path $Folder (".writetest_{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
            [IO.File]::WriteAllText($tmp, 'ok')
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            return $true
        } catch {
            throw "Folder is not writable: $Folder – $($_.Exception.Message)"
        }
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

# One-time visibility note for snapshot cadence approximation
if ($UseVlcSnapshots) {
    Write-Message -Level Warn -Message "Snapshot mode uses frame-count ratio approximation (1/N frames) derived from video FPS; exact N FPS is not guaranteed. For precise time-based cadence, use GDI+ mode."
}

# FFprobe presence note (duration fallback clarity)
if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Message -Level Warn -Message "FFprobe not found in PATH. Duration detection will rely on Windows file metadata; auto-stop may be less reliable for some formats. Install FFmpeg (ffprobe) and ensure it’s on PATH for best results."
}

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
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TargetPath,
        [ValidateRange(1,10)][int]$MaxAttempts = 3,
        [int]$Width,
        [int]$Height
    )
    if (($PSBoundParameters.ContainsKey('Width') -xor $PSBoundParameters.ContainsKey('Height')) -or
        (($PSBoundParameters.ContainsKey('Width') -and $Width -le 0) -or ($PSBoundParameters.ContainsKey('Height') -and $Height -le 0))) {
        throw "Width/Height must be provided together and be positive integers."
    }
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

function Get-VideoDurationViaShell {
    <#
    .SYNOPSIS
    Get video duration using Windows Shell COM GetDetailsOf method.

    .DESCRIPTION
    Uses Shell.Application to read localized Details columns and parse duration.
    Falls back to canonical ExtendedProperty values when available. Avoids
    Split-Path parameter-set conflicts by using .NET path helpers.

    .PARAMETER Path
    Full path to the video file.

    .OUTPUTS
    [double] seconds, or $null if not available.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $shell  = $null
    $folder = $null
    $item   = $null
    try {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-Debug "Shell COM duration: input path is null/empty"
            return $null
        }

        # Normalize components without Split-Path (avoid parameter-set conflicts)
        try { $full = [System.IO.Path]::GetFullPath($Path) } catch { $full = $Path }
        $dir  = [System.IO.Path]::GetDirectoryName($full)
        $leaf = [System.IO.Path]::GetFileName($full)

        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) {
            Write-Debug "Shell COM duration: invalid or missing directory for '$Path' (dir='$dir')"
            return $null
        }

        $shell  = New-Object -ComObject Shell.Application
        $folder = $shell.NameSpace($dir)
        if (-not $folder) {
            Write-Debug "Shell COM duration: NameSpace returned null for '$dir'"
            return $null
        }

        $item = $folder.ParseName($leaf)
        if (-not $item) {
            Write-Debug "Shell COM duration: ParseName failed for '$leaf' in '$dir'"
            return $null
        }

        # Method 1: scan localized Details columns
        for ($i = 0; $i -lt 300; $i++) {
            $header = $folder.GetDetailsOf($null, $i)
            if ($header -match '^(?:Length|Duration|Durée|Dauer|Duración)\b') {
                $v = $folder.GetDetailsOf($item, $i)
                if ($v -and $v.Trim()) {
                    Write-Debug "Duration from Shell COM column $i ($header): $v"
                    $t = $v.Trim()

                    # HH:MM:SS(.ms)
                    if ($t -match '^\s*(\d{1,2}):(\d{2}):(\d{2})(?:[.,](\d{1,3}))?\s*$') {
                        $hours   = [int]$matches[1]
                        $minutes = [int]$matches[2]
                        $seconds = [int]$matches[3]
                        $ms      = if ($matches[4]) { [int]$matches[4] } else { 0 }
                        return ($hours * 3600 + $minutes * 60 + $seconds) + ($ms / 1000.0)
                    }

                    # MM:SS(.ms)
                    if ($t -match '^\s*(\d{1,2}):(\d{2})(?:[.,](\d{1,3}))?\s*$') {
                        $minutes = [int]$matches[1]
                        $seconds = [int]$matches[2]
                        $ms      = if ($matches[4]) { [int]$matches[4] } else { 0 }
                        return ($minutes * 60 + $seconds) + ($ms / 1000.0)
                    }

                    # HH:MM:SS;ff (drop frame count)
                    if ($t -match '^\s*(\d{1,2}):(\d{2}):(\d{2});\d+\s*$') {
                        $hours   = [int]$matches[1]
                        $minutes = [int]$matches[2]
                        $seconds = [int]$matches[3]
                        return ($hours * 3600 + $minutes * 60 + $seconds)
                    }
                }
            }
        }

        # Method 2: canonical ExtendedProperty fallbacks
        foreach ($prop in @('System.Media.Duration', 'Duration')) {
            try {
                $v = $item.ExtendedProperty($prop)
                if ($v) {
                    Write-Debug "Duration from ExtendedProperty $prop`: $v"
                    if ($v -is [string] -and $v.Trim()) {
                        try { return [TimeSpan]::Parse($v).TotalSeconds } catch {}
                    }
                    if ($v -is [long] -or $v -is [int]) {
                        return [double]$v / 10000000.0  # ticks (100ns) -> seconds
                    }
                }
            } catch {
                Write-Debug "ExtendedProperty $prop failed: $($_.Exception.Message)"
            }
        }

        Write-Debug "No duration properties found via Shell COM for '$Path'"
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
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)
    try {
        $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
        if (-not $ffprobe) {
            Write-Debug "FFprobe not found in PATH"
            return $null
        }
        
        Write-Debug "Trying FFprobe for duration detection"
        # Pass path after `--` to prevent ffprobe parsing it as an option and ensure odd paths are safe
        $result = & ffprobe -v quiet -show_entries format=duration -of csv=p=0 -- "$Path" 2>$null
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
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)
    
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
        # Normalize path via .NET helpers to avoid Split-Path parameter-set conflicts
        try {
            $full  = [System.IO.Path]::GetFullPath($Path)
        } catch {
            Write-Debug "Get-VideoFps: invalid path '$Path' – $($_.Exception.Message)"
            return $null
        }
        $dir   = [System.IO.Path]::GetDirectoryName($full)
        $leaf  = [System.IO.Path]::GetFileName($full)
        if (-not $dir -or -not $leaf) {
            Write-Debug "Get-VideoFps: could not resolve directory/file from '$full'"
            return $null
        }

        $shell  = New-Object -ComObject Shell.Application
        $folder = $shell.NameSpace($dir)
        if (-not $folder) { Write-Debug "Get-VideoFps: Shell.NameSpace failed for '$dir'"; return $null }

        $item   = $folder.ParseName($leaf)
        if (-not $item)   { Write-Debug "Get-VideoFps: folder.ParseName failed for '$leaf'"; return $null }

        # Method 1: GetDetailsOf scan (works across locales)
        for ($i = 0; $i -lt 300; $i++) {
            $header = $folder.GetDetailsOf($null, $i)
            if ($header -match "Frame rate|FPS|Video frame rate|Fréquence d'images|Bildrate") {
                $v = $folder.GetDetailsOf($item, $i)
                if ($v -and $v.Trim()) {
                    Write-Debug "Frame rate from Shell COM column $i ($header): $v"

                    # Accept "29.97 fps" / "29,97 fps"
                    if ($v -match "(\d+[\.,]?\d*)\s*fps") {
                        $num = $matches[1].Replace(',', '.')
                        if ([double]::TryParse($num, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]([double]$null))) {
                            $fps = [double]::Parse($num, [System.Globalization.CultureInfo]::InvariantCulture)
                            if ($fps -gt 0) { return $fps }
                        }
                    }
                    # Accept plain decimal "29.97" or "29,97"
                    if ($v -match "^(\d+[\.,]?\d*)$") {
                        $num = $matches[1].Replace(',', '.')
                        if ([double]::TryParse($num, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]([double]$null))) {
                            $fps = [double]::Parse($num, [System.Globalization.CultureInfo]::InvariantCulture)
                            if ($fps -gt 0) { return $fps }
                        }
                    }
                    # Accept fractional notation "30000/1001"
                    if ($v -match "^\s*(\d+)\s*/\s*(\d+)\s*$") {
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

        # Method 2: ExtendedProperty fallback (milliframes per second)
        try {
            $v = $item.ExtendedProperty('System.Video.FrameRate')
            if ($null -ne $v) {
                Write-Debug "Frame rate from ExtendedProperty System.Video.FrameRate: $v"
                if ($v -is [long] -or $v -is [int]) {
                    $fps = [double]$v / 1000.0
                    if ($fps -gt 0) { return $fps }
                }
            }
        } catch {
            Write-Debug "ExtendedProperty System.Video.FrameRate failed: $($_.Exception.Message)"
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
Compute per-video context shared by both capture modes.
.DESCRIPTION
Resolves snapshot prefix & pre-run counts, duration/stopAt, and a per-video deadline.
Returns an object with ScenePrefix, PreCount, StopAtSeconds, PerVideoDeadline.
.PARAMETER VideoPath
Full path to the video.
.PARAMETER SaveFolder
Destination folder for frames.
.PARAMETER UseVlcSnapshots
If set, handles snapshot hygiene (ClearSnapshotsBeforeRun) and pre/post counting.
.PARAMETER ClearSnapshotsBeforeRun
Deletes existing <prefix>*.png before run when in snapshot mode.
.PARAMETER DisableAutoStop
Skips duration-based stopAt calculation when set.
.PARAMETER AutoStopGraceSeconds
Seconds added beyond detected duration (if any).
.OUTPUTS
PSCustomObject
#>
function Initialize-VideoContext {
    param(
        [Parameter(Mandatory)][string]$VideoPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [switch]$UseVlcSnapshots,
        [switch]$ClearSnapshotsBeforeRun,
        [switch]$DisableAutoStop,
        [int]$AutoStopGraceSeconds = 2
    )
    # One-time SaveFolder writability preflight via helper (module or fallback)
    if (-not $script:__SaveFolderWriteChecked) {
        Assert-FolderWritable -Folder $SaveFolder | Out-Null
        $script:__SaveFolderWriteChecked = $true
    }
    $scenePrefix = ([IO.Path]::GetFileNameWithoutExtension($VideoPath)) + '_'
    $preCount = 0
    if ($UseVlcSnapshots) {
        if ($ClearSnapshotsBeforeRun) {
            Get-ChildItem -Path $SaveFolder -Filter "$scenePrefix*.png" -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            $preCount = 0
        } else {
            $preCount = (Get-ChildItem -Path $SaveFolder -Filter "$scenePrefix*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        }
    }

    $stopAt = 0.0
    if (-not $DisableAutoStop) {
        $dur = Get-VideoDurationSeconds -Path $VideoPath
        if ($dur -and $dur -gt 0) {
            $stopAt = [double]$dur + [double]$AutoStopGraceSeconds
            Write-Debug "Duration detection: raw=$dur sec, grace=$AutoStopGraceSeconds sec, stopAt=$stopAt sec"
        } else {
            Write-Debug "Duration detection: unable to detect duration, no auto-stop will be applied"
        }
    } else {
        Write-Debug "Auto-stop disabled via -DisableAutoStop parameter"
    }

    $deadline = if ($stopAt -gt 0) { (Get-Date).AddSeconds($stopAt) } else { $null }
    [pscustomobject]@{
        ScenePrefix      = $scenePrefix
        PreCount         = $preCount
        StopAtSeconds    = $stopAt
        PerVideoDeadline = $deadline
    }
}

<#
.SYNOPSIS
Post-capture measurement/validation and (snapshot) FPS deviation handling.
.DESCRIPTION
Determines whether frames were produced and computes frames delta. In snapshot mode,
also computes achieved FPS and warns if it deviates ≥20% from the requested value.
.OUTPUTS
PSCustomObject with HadFrames, FramesDelta, AchievedFps.
#>
if (-not (Get-Command Measure-PostCapture -ErrorAction SilentlyContinue)) {
function Measure-PostCapture {
    param(
        [switch]$UseVlcSnapshots,
        [Parameter(Mandatory)][string]$SaveFolder,
        [Parameter(Mandatory)][string]$ScenePrefix,
        [int]$PreCount = 0,
        $GdiResult,
        $SnapResult,
        [Parameter(Mandatory)][int]$RequestedFps,
        [Parameter(Mandatory)][string]$VideoPath
    )
    $hadFrames = $false
    $framesDelta = 0
    $achieved = $null

    if ($UseVlcSnapshots) {
        $postCount = (Get-ChildItem -Path $SaveFolder -Filter "$ScenePrefix*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $framesDelta = $postCount - $PreCount
        $hadFrames   = ($framesDelta -gt 0)
        if ($SnapResult -and $SnapResult.ElapsedSeconds -gt 0) {
            $achieved = [Math]::Round($framesDelta / $SnapResult.ElapsedSeconds, 3)
            Write-Debug "Snapshot achieved FPS: $achieved (requested=$RequestedFps, frames=$framesDelta, elapsed=$($SnapResult.ElapsedSeconds)s)"
            if ($RequestedFps -gt 0) {
                $dev = [Math]::Abs($achieved - $RequestedFps) / [double]$RequestedFps
                if ($dev -ge 0.20) {
                    Write-Message -Level Warn -Message ("Snapshot cadence deviates by {0:P0} from requested FPS (requested={1}, achieved={2}) for: {3}" -f $dev, $RequestedFps, $achieved, $VideoPath)
                }
            }
        }
    } else {
        $framesSaved = if ($null -ne $GdiResult) { [int]$GdiResult.FramesSaved } else { 0 }
        $hadFrames   = ($framesSaved -gt 0)
        $framesDelta = $framesSaved
        $achieved    = ($GdiResult?.AchievedFps)
    }

    [pscustomobject]@{
        HadFrames   = [bool]$hadFrames
        FramesDelta = [int]$framesDelta
        AchievedFps = $achieved
    }
}
}

<#
.SYNOPSIS
Perform GDI+ (desktop) capture until VLC exits or a per-video deadline is reached.
.DESCRIPTION
Uses a monotonic stopwatch scheduler to reduce drift from PNG saves. Returns frame
count, elapsed seconds, error state, and achieved FPS (logged in debug).
.PARAMETER Process
The VLC process to monitor.
.PARAMETER SaveFolder
Where PNGs are written.
.PARAMETER VideoBaseName
Prefix for frame filenames (<VideoBaseName>_######.png).
.PARAMETER IntervalMs
Desired interval between frames in milliseconds.
.PARAMETER Legacy1080p
If set, captures a fixed 1920x1080 region (legacy behavior).
.PARAMETER PerVideoDeadline
Optional deadline time; capture stops when reached.
.OUTPUTS
PSCustomObject with FramesSaved, ElapsedSeconds, HadError, AchievedFps.
#>
function Invoke-GdiCapture {
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory)][string]$SaveFolder,
        [Parameter(Mandatory)][string]$VideoBaseName,
        [Parameter(Mandatory)][int]$IntervalMs,
        [switch]$Legacy1080p,
        [datetime]$PerVideoDeadline
    )
    $frameIndex = 0
    $savedThisRun = 0
    $hadError = $false

    $fpsSw = [System.Diagnostics.Stopwatch]::StartNew()
    $sw    = [System.Diagnostics.Stopwatch]::StartNew()
    $next  = $sw.ElapsedMilliseconds  # capture first frame immediately

    while (-not $Process.HasExited) {
        if ($PerVideoDeadline -and (Get-Date) -ge $PerVideoDeadline) {
            $elapsed = $fpsSw.Elapsed.TotalSeconds
            Write-Debug "Per-video deadline reached after $elapsed seconds of capture"
            break
        }

        $filename = ('{0}_{1:D6}.png' -f $VideoBaseName, $frameIndex)
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
            $hadError = $true
        }
        $next += $IntervalMs
        $sleep = [int]($next - $sw.ElapsedMilliseconds)
        if ($sleep -gt 0) { Start-Sleep -Milliseconds $sleep }
    }

    $fpsSw.Stop()
    $sw.Stop()
    $elapsedSec  = [Math]::Max(0.001, $fpsSw.Elapsed.TotalSeconds)
    $achievedFps = [Math]::Round($savedThisRun / $elapsedSec, 3)
    Write-Debug "GDI+ achieved FPS: $achievedFps (frames=$savedThisRun, elapsed=${elapsedSec}s)"

    [pscustomobject]@{
        FramesSaved    = $savedThisRun
        ElapsedSeconds = $elapsedSec
        HadError       = $hadError
        AchievedFps    = $achievedFps
    }
}

<#
.SYNOPSIS
Perform snapshot-mode (VLC scene filter) monitoring until exit or timeout.
.DESCRIPTION
Waits for the VLC process to finish, enforcing a max wait derived from StopAtSeconds
(+5s) or 300s fallback. Returns elapsed seconds and whether a timeout occurred.
.PARAMETER Process
The VLC process to monitor.
.PARAMETER StopAtSeconds
Optional content duration + grace; when set, max wait = StopAtSeconds + 5s.
.OUTPUTS
PSCustomObject with ElapsedSeconds and TimedOut.
#>
function Invoke-SnapshotCapture {
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
        [double]$StopAtSeconds = 0
    )
    $processStart = Get-Date
    $maxWait = if ($StopAtSeconds -gt 0) { $StopAtSeconds + 5 } else { 300 }
    Write-Debug "Snapshot mode: monitoring VLC process (max wait: $maxWait sec)"

    $timedOut = $false
    while (-not $Process.HasExited) {
        Start-Sleep -Milliseconds 200
        $elapsed = (New-TimeSpan -Start $processStart -End (Get-Date)).TotalSeconds
        if ($elapsed -ge $maxWait) {
            Write-Debug "VLC process timeout reached ($elapsed sec), force terminating"
            Write-Message -Level Warn -Message "VLC timeout reached after $([int]$elapsed)s; terminating process."
            try {
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
                Wait-Process -Id $Process.Id -Timeout 3000 -ErrorAction SilentlyContinue
                $Process.Refresh()
                Write-Debug "Process termination completed"
            } catch {
                Write-Debug "Error during process termination: $($_.Exception.Message)"
            }
            $timedOut = $true
            break
        }
    }

    $finalElapsed = (New-TimeSpan -Start $processStart -End (Get-Date)).TotalSeconds
    Write-Debug "VLC process completed after $finalElapsed seconds"
    [pscustomobject]@{
        ElapsedSeconds = [Math]::Max(0.001, $finalElapsed)
        TimedOut       = $timedOut
    }
}
<#
.SYNOPSIS
Builds VLC command-line switches common to all modes.

.DESCRIPTION
Returns an array of VLC arguments that are safe for both GDI+ (GUI) and snapshot
(headless) modes. If StopAtSeconds > 0, appends --stop-time with the rounded
second value. Emits Write-Debug messages describing the applied stop-time.

.PARAMETER StopAtSeconds
Optional upper bound (seconds) for playback. When > 0, a rounded value is
passed to VLC via --stop-time. When 0, no stop-time is applied.

.OUTPUTS
string[]  # Array of individual argument tokens.

.EXAMPLE
# Compose a common arg set with a 125s stop time
$common = Get-VlcArgsCommon -StopAtSeconds 125

.NOTES
Internal helper used by Start-Vlc.
#>
function Get-VlcArgsCommon {
    param([double]$StopAtSeconds = 0)

    $vlcArgs = @(
        '--no-qt-privacy-ask',
        '--no-video-title-show',
        '--no-loop',
        '--no-repeat',
        '--rate', '1',
        '--play-and-exit'
    )

    if ($StopAtSeconds -gt 0) {
        $roundedStop = [int][Math]::Round($StopAtSeconds)
        $vlcArgs += @('--stop-time', [string]$roundedStop)
        Write-Debug "VLC will be configured with --stop-time=$roundedStop (from stopAt=$StopAtSeconds)"
    } else {
        Write-Debug "No --stop-time parameter (stopAt=$StopAtSeconds)"
    }
    return ,$vlcArgs
}

<#
.SYNOPSIS
Builds VLC scene-filter arguments for snapshot mode (headless).

.DESCRIPTION
Returns an array of VLC arguments that enable the 'scene' video filter and write
PNG snapshots to the specified SaveFolder using a <VideoBase>_ prefix. The
cadence uses VLC 3.x's frame-ratio approximation (1/N frames). N is derived from
the detected video FPS (via Get-VideoFps) and the requested FramesPerSecond,
falling back to 30 FPS if the file's FPS cannot be detected. Writes helpful
Write-Debug traces showing detected FPS, requested FPS, and the chosen ratio.

.PARAMETER VideoPath
Full path to the input video. Used for the scene prefix.

.PARAMETER SaveFolder
Destination folder for scene snapshots.

.PARAMETER RequestedFps
Desired capture cadence (used to derive the 1/N frame ratio).

.OUTPUTS
string[]  # Array of individual argument tokens.

.EXAMPLE
# Build snapshot args for a 2 FPS target cadence
$snap = Get-VlcArgsSnapshot -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\shots' -RequestedFps 2

.NOTES
Internal helper used by Start-Vlc for -UseVlcSnapshots.
#>
function Get-VlcArgsSnapshot {
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$VideoPath,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
        [Parameter(Mandatory)][ValidateRange(1,1000)][int]$RequestedFps
    )
    $vfps  = Get-VideoFps -Path $VideoPath
    $base  = if ($vfps -and $vfps -gt 0) { [double]$vfps } else { 30.0 }
    $ratio = [int][Math]::Max(1, [Math]::Round($base / [double]$RequestedFps))

    Write-Debug "Snapshots (VLC 3.x): video_fps=$base; requested=$RequestedFps; using --scene-ratio=$ratio"
    if ($RequestedFps -gt [int][Math]::Ceiling($base)) {
        Write-Message -Level Warn -Message (
            "Requested -FramesPerSecond ({0}) exceeds detected video FPS ({1:0.###}). " +
            "Snapshot cadence will be limited to at most the source FPS (1:1 frames). " +
            "To avoid this downgrade, lower -FramesPerSecond or use GDI+ for exact timing."
        ) -f $RequestedFps, $base
    }

    return ,@(
        '--intf', 'dummy',
        '--video-filter=scene',
        "--scene-path=""$SaveFolder""",
        "--scene-prefix=""$([IO.Path]::GetFileNameWithoutExtension($VideoPath))_""",
        '--scene-format=png',
        "--scene-ratio=$ratio"
    )
}

<#
.SYNOPSIS
Builds VLC UI arguments for GDI+ (desktop) capture.

.DESCRIPTION
Returns UI-related VLC arguments when -GdiFullscreen is requested
(--fullscreen --video-on-top --qt-minimal-view) to reduce UI chrome in
desktop screenshots. Returns an empty array when not requested.

.PARAMETER GdiFullscreen
When set, returns the full-screen/on-top/minimal-UI switches.

.OUTPUTS
string[]  # Array of individual argument tokens.

.EXAMPLE
# Full-screen VLC window for desktop capture
$gdi = Get-VlcArgsGdi -GdiFullscreen

.NOTES
Internal helper used by Start-Vlc for GDI+ mode.
#>
function Get-VlcArgsGdi {
    param([switch]$GdiFullscreen)
    if ($GdiFullscreen) {
        return ,@('--fullscreen', '--video-on-top', '--qt-minimal-view')
    }
    return @()
}

<#
.SYNOPSIS
Register a launched VLC PID in the per-run registry.
.DESCRIPTION
Appends the PID to $PidRegistry so engine-exit/Ctrl+C handlers can clean it up.
.PARAMETER ProcessId
Process ID to add to the registry.
#>
function Register-RunPid {
    param([Parameter(Mandatory)][int]$ProcessId)
    Add-Content -LiteralPath $PidRegistry -Value $ProcessId
}

<#
.SYNOPSIS
Remove a PID from the per-run registry.
.DESCRIPTION
Edits $PidRegistry to drop the specified PID after the process has been stopped.
.PARAMETER ProcessId
Process ID to remove from the registry.
#>
function Unregister-RunPid {
    param([Parameter(Mandatory)][int]$ProcessId)
    if (Test-Path -LiteralPath $PidRegistry) {
        (Get-Content -LiteralPath $PidRegistry | Where-Object { $_ -ne "$ProcessId" }) |
            Set-Content -LiteralPath $PidRegistry
    }
}

<#
.SYNOPSIS
Launch vlc.exe with given arguments and perform startup monitoring.
.DESCRIPTION
Starts VLC, records its PID, and waits up to VlcStartupTimeoutSeconds to confirm
it's running. A clean ExitCode=0 during this window is treated as a valid early
completion (short clips). Returns the Process object or $null on failure.
.PARAMETER Arguments
Array of VLC CLI arguments to pass, already composed.
.OUTPUTS
System.Diagnostics.Process
#>
function Invoke-VlcProcess {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = 'vlc'
    $psi.Arguments = ($Arguments -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $startTime = Get-Date
    $null = $p.Start()
    Register-RunPid -ProcessId $p.Id

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
Starts VLC for a single video with arguments composed per capture mode.

.DESCRIPTION
Launches vlc.exe configured for:
  • GDI+ desktop capture (GUI window). If -GdiFullscreen is set, VLC runs
    full-screen, on-top, with minimal UI to reduce chrome in screenshots.
  • Snapshot mode (-UseVlcSnapshots) using the 'scene' filter (headless).
    Cadence is frame-ratio based (1/N frames) derived from detected video FPS.

Common flags disable title overlays and user loop/repeat preferences. If a
clean ExitCode=0 occurs during the startup wait window, it is treated as a
successful early completion (very short clips). The function records the VLC
PID in a per-run registry file so Ctrl+C/engine-exit handlers can terminate only
processes launched by this script.

This function delegates argument construction to:
  - Get-VlcArgsCommon     (shared flags, optional --stop-time)
  - Get-VlcArgsSnapshot   (scene filter + 1/N frame ratio)
  - Get-VlcArgsGdi        (optional full-screen UI switches)

.PARAMETER VideoPath
Full path to the video file.

.PARAMETER SaveFolder
Destination for snapshot files when -UseVlcSnapshots is enabled.
(Not used by GDI+ capture itself, but required by the signature.)

.PARAMETER UseVlcSnapshots
When set, enables headless snapshot capture (video-frame only).

.PARAMETER StopAtSeconds
Optional stop time (seconds). When > 0, Start-Vlc passes --stop-time.

.OUTPUTS
System.Diagnostics.Process  # Process object for the running VLC instance (may have exited).

.EXAMPLE
# GDI+ capture (desktop), with full-screen VLC window
$proc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\shots' -StopAtSeconds 65

.EXAMPLE
# Snapshot mode (headless; no desktop UI in images)
$proc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\shots' -UseVlcSnapshots -StopAtSeconds 65

.NOTES
- Writes the launched PID to the per-run registry (.vlc_pids_<guid>.txt) so
  event handlers can clean up reliably.
- Emits Write-Debug traces for args and startup behavior.
#>
function Start-Vlc {
    param(
        [Parameter(Mandatory)][string]$VideoPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [switch]$UseVlcSnapshots,
        [double]$StopAtSeconds = 0
    )

    # Assemble arguments: file path, then mode-specific args, then common args
    $vlcargs = @("`"$VideoPath`"")
    if ($UseVlcSnapshots) {
        $vlcargs += Get-VlcArgsSnapshot -VideoPath $VideoPath -SaveFolder $SaveFolder -RequestedFps $FramesPerSecond
    } else {
        $vlcargs += Get-VlcArgsGdi -GdiFullscreen:$GdiFullscreen
    }
    $vlcargs += Get-VlcArgsCommon -StopAtSeconds $StopAtSeconds

    Write-Debug ("VLC args: " + ($vlcargs -join ' '))
    return (Invoke-VlcProcess -Arguments $vlcargs)
}

<#
.SYNOPSIS
Stops VLC gracefully, with force-kill and deterministic exit.

.DESCRIPTION
Attempts CloseMainWindow (no-op in --intf dummy), then waits briefly for exit.
If still running, uses Stop-Process -Force and then Wait-Process to ensure the
process actually terminates. This deterministic termination helps make ExitCode
readable and consistent on all code paths.

.PARAMETER Process
The VLC process object to stop.

.OUTPUTS
None.

.EXAMPLE
try {
  $vlc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\shots'
  # ... work ...
} finally {
  if ($vlc) { Stop-Vlc -Process $vlc }
}

.NOTES
Safe for use in finally blocks; exceptions are swallowed to avoid masking the
original error path.
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
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TargetPath,
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
Ensure required Python modules exist; install them if missing.
.DESCRIPTION
Checks for importability of 'numpy' and 'cv2' in the current 'python' interpreter.
If missing, bootstraps pip (ensurepip) if needed and attempts install via pip.
Returns $true when modules are importable after the process; $false otherwise.
.OUTPUTS
Boolean
#>
function Confirm-PythonModules {
    param()
    # Helper to run a python command and capture output
    function Invoke-Python {
        param([Parameter(Mandatory)][string[]]$Arguments)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'python'
        foreach ($arg in $Arguments) { $psi.ArgumentList.Add($arg) }
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::new()
        $p.StartInfo = $psi
        $null = $p.Start()
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        [pscustomobject]@{ Code=$p.ExitCode; Out=$stdout; Err=$stderr }
    }

    $checkCode = 'import importlib.util,sys;mods=["numpy","cv2"];missing=[m for m in mods if importlib.util.find_spec(m) is None];print(",".join(missing))'
    $check = Invoke-Python -Arguments @('-c', $checkCode)
    if ($check.Code -ne 0) {
        Write-Debug "Module check failed: $($check.Err)"
        # If python itself can't run the check, bail early.
        return $false
    }
    $missing = @()
    if ($check.Out) {
        $missing = ($check.Out.Trim() -split ',') | Where-Object { $_ -and $_.Trim() }
    }
    if (-not $missing -or $missing.Count -eq 0) {
        Write-Debug "All required Python modules present."
        return $true
    }

    Write-Message -Level Info -Message ("Missing Python modules: {0}. Attempting auto-install..." -f ($missing -join ', '))

    # Ensure pip exists
    $pipCheck = Invoke-Python -Arguments @('-m', 'pip', '--version')
    if ($pipCheck.Code -ne 0) {
        Write-Debug "pip not available; attempting ensurepip. stderr: $($pipCheck.Err)"
        $ensure = Invoke-Python -Arguments @('-m', 'ensurepip', '--default-pip')
        if ($ensure.Code -ne 0) {
            Write-Message -Level Error -Message ("Unable to bootstrap pip (ensurepip failed). stderr: {0}" -f $ensure.Err)
            return $false
        }
    }

    # Map import names to packages
    $pkgMap = @{
        'numpy' = 'numpy'
        'cv2'   = 'opencv-python'
    }
    $packages = $missing | ForEach-Object { $pkgMap[$_] } | Where-Object { $_ }
    if (-not $packages -or $packages.Count -eq 0) {
        Write-Message -Level Error -Message "Cannot resolve package names for required modules: $($missing -join ', ')"
        return $false
    }

    $installArgs = @('-m', 'pip', 'install', '--disable-pip-version-check') + $packages
    $install = Invoke-Python -Arguments $installArgs
    if ($install.Code -ne 0) {
        Write-Message -Level Error -Message ("pip install failed. stderr: {0}" -f $install.Err)
        return $false
    }

    # Recheck
    $recheck = Invoke-Python -Arguments @('-c', $checkCode)
    if ($recheck.Code -ne 0) {
        Write-Message -Level Error -Message ("Module re-check failed after install. stderr: {0}" -f $recheck.Err)
        return $false
    }
    $missing2 = @()
    if ($recheck.Out) {
        $missing2 = ($recheck.Out.Trim() -split ',') | Where-Object { $_ -and $_.Trim() }
    }
    if ($missing2 -and $missing2.Count -gt 0) {
        Write-Message -Level Error -Message ("Required modules still missing after install: {0}" -f ($missing2 -join ', '))
        return $false
    }

    Write-Message -Level Info -Message "Python module auto-install completed."
    return $true
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
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PythonScriptPath,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
        [string]$ResumeFile
    )

    try {
        $versionResult = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null
        $versionParts = $versionResult.ToString().Trim() -split '\.'
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]
        if ($major -ne 3 -or $minor -lt 9) {
            throw "Insufficient version: Python $major.$minor detected"
        }
    } catch {
        $pv = (& python --version) 2>&1
        throw "Python 3.9+ required (found: $pv). Install Python ≥3.9 and ensure 'python' is on PATH."
    }

    if (-not (Test-Path -LiteralPath $PythonScriptPath)) {
        throw "PythonScriptPath not found: $PythonScriptPath. Override with -PythonScriptPath (default assumes ..\python\crop_colours.py)."
    }

    # Ensure required Python modules exist (or install them)
    if (-not (Confirm-PythonModules)) {
        throw "Required Python modules (numpy/cv2) are missing and automatic installation failed. [MODULE_INSTALL_FAILED]"
    }

    if (-not (Test-Path -LiteralPath $SaveFolder)) {
        throw "SaveFolder not found: $SaveFolder. Create it or pass -SaveFolder."
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
        $PythonScriptPath,
        '--input', $SaveFolder,
        '--skip-bad-images',
        '--allow-empty',
        '--recurse'
    ) + $resumeArg

    Write-Debug ("Python args: " + ($pyArgs -join ' '))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'python'
    foreach ($arg in $pyArgs) { $psi.ArgumentList.Add($arg) }
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

# Clean up any existing handlers from previous runs
try {
    Get-EventSubscriber -SourceIdentifier CtrlCHandler -ErrorAction Stop | Unregister-Event
} catch { }

try {
    Get-EventSubscriber -SourceIdentifier PowerShell.Exiting -ErrorAction Stop | Unregister-Event  
} catch { }

# Remove any leftover jobs
Get-Job | Where-Object Name -In @('CtrlCHandler', 'PowerShell.Exiting') | Remove-Job -Force -ErrorAction SilentlyContinue

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
    Write-Message -Level Error -Message "VLC (vlc.exe) not found in PATH. Install VLC or add it to PATH, then re-run."
    exit 1
}

# Preflight: require VLC when capturing (not needed for -CropOnly which returns above)
$vlcCmd = Get-Command vlc -ErrorAction SilentlyContinue
if (-not $vlcCmd) {
    Write-Message -Level Error -Message "VLC (vlc.exe) not found in PATH. Please install VLC or add it to PATH."
    exit 2
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
    $hadFrames = $false
    $savedThisRun = 0
    $ctx = Initialize-VideoContext -VideoPath $video.FullName -SaveFolder $SaveFolder `
        -UseVlcSnapshots:$UseVlcSnapshots -ClearSnapshotsBeforeRun:$ClearSnapshotsBeforeRun `
        -DisableAutoStop:$DisableAutoStop -AutoStopGraceSeconds $AutoStopGraceSeconds
    $scenePrefixForThisVideo = $ctx.ScenePrefix
    $preCount = $ctx.PreCount
    try {
        $stopAt = $ctx.StopAtSeconds
        
        $vlc = Start-Vlc -VideoPath $video.FullName -SaveFolder $SaveFolder `
                    -UseVlcSnapshots:$UseVlcSnapshots -StopAtSeconds:$stopAt

        if (-not $vlc) {
            throw "Failed to start VLC for: $($video.FullName)"
        }

        if ($UseVlcSnapshots) {
            $snapResult = Invoke-SnapshotCapture -Process $vlc -StopAtSeconds $stopAt
        } else {
            $videoBase = [IO.Path]::GetFileNameWithoutExtension($video.Name)
            $perVideoDeadline = $ctx.PerVideoDeadline
            if ($perVideoDeadline) {
                Write-Debug "GDI+ capture: per-video deadline set to $($perVideoDeadline.ToString('HH:mm:ss'))"
            } else {
                Write-Debug "GDI+ capture: no per-video deadline (unlimited capture)"
            }
            $gdiResult = Invoke-GdiCapture -Process $vlc -SaveFolder $SaveFolder -VideoBaseName $videoBase `
                                          -IntervalMs $intervalMs -Legacy1080p:$Legacy1080p -PerVideoDeadline $perVideoDeadline
            $errorDuringCapture = $gdiResult.HadError
        }
    }
    catch {
        $errorDuringCapture = $true
        Write-Message -Level Error -Message $_.Exception.Message
    }
    finally {
        if ($vlc) {
            Stop-Vlc -Process $vlc
            # remove from PID registry after termination
            Unregister-RunPid -ProcessId $vlc.Id
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

    # Post-run validation + (snapshot) FPS deviation handling
    $post = Measure-PostCapture -UseVlcSnapshots:$UseVlcSnapshots -SaveFolder $SaveFolder `
                                 -ScenePrefix $scenePrefixForThisVideo -PreCount $preCount `
                                 -GdiResult $gdiResult -SnapResult $snapResult `
                                 -RequestedFps $FramesPerSecond -VideoPath $video.FullName
    $hadFrames   = $post.HadFrames
    $framesDelta = $post.FramesDelta

    # Recognize per-video timeout (duration + grace) in snapshot mode as a successful completion
    # This is distinct from the 300s fallback timeout (unknown duration).
    $timedOutPerVideo = ($UseVlcSnapshots -and $snapResult -and $snapResult.TimedOut -and ($stopAt -gt 0))

    # Unified debug output that works for both modes
    $processingTime = if ($videoStartTime) { (New-TimeSpan -Start $videoStartTime -End (Get-Date)).TotalSeconds } else { 0 }
    Write-Debug "Video processing complete: ExitCode=$vlcExit, processingTime=$processingTime sec, frames=$framesDelta, hadErrors=$errorDuringCapture"

    # Final outcome evaluation
    # Consider per-video timeout (duration + grace reached) as processed even if VLC was force-terminated and no frames were produced.
    $ok = $timedOutPerVideo -or ((-not $errorDuringCapture) -and ($vlcExit -eq 0) -and $hadFrames)

    if ($ok) {
        if ($timedOutPerVideo) {
            Write-Message -Level Info -Message "Timed out at per-video limit (duration + grace); marking processed: $($video.FullName)"
        }
        if (Add-ContentWithRetry -Path $ProcessedLogPath -Value $video.FullName) {
            Write-Message -Level Info -Message "Marked processed: $($video.FullName)"
        } else {
            Write-Message -Level Error -Message "Processed OK, but failed to update processed log: $ProcessedLogPath"
            exit 1
        }
    } else {
        # Provide specific feedback for timeout cases
        if ($UseVlcSnapshots -and $vlcExit -ne 0 -and -not $hadFrames) {
            $elapsedForMsg = if ($snapResult) { [int]$snapResult.ElapsedSeconds } else { 0 }
            if ($stopAt -gt 0 -and $snapResult -and $snapResult.TimedOut) {
                # This branch should be rare now because $timedOutPerVideo already set $ok=true.
                Write-Message -Level Warn -Message "Video timed out after ${elapsedForMsg}s; not marking as processed: $($video.FullName). Consider increasing -AutoStopGraceSeconds or verifying the media decodes correctly."
            } else {
                Write-Message -Level Warn -Message "Video timed out after ${elapsedForMsg}s; not marking as processed: $($video.FullName)"
            }
        } elseif (-not $hadFrames) {
            Write-Message -Level Warn -Message "No frames captured; not marking as processed: $($video.FullName). Try -GdiFullscreen (GDI+) or -UseVlcSnapshots, and check SaveFolder write permissions."
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
    # Only hard-fail the run when module auto-installation was the reason
    if ($_.Exception.Message -like '*[MODULE_INSTALL_FAILED]*') {
        exit 1
    }
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