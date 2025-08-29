<#
.SYNOPSIS
Captures video frames from VLC or the desktop and (optionally) runs a Python cropper.

.DESCRIPTION
Plays each video file via VLC and saves periodic screenshots to a target folder.
Two capture approaches are supported:
  1) Desktop capture via GDI+ (default) – generic, no VLC filters required.
  2) VLC scene snapshots (opt-in via -UseVlcSnapshots) – captures only the video frame.

Major behaviours and safeguards:
  - Time limit: if reached, capture stops, VLC is terminated cleanly, and the video is
    NOT logged as processed (prevents false “processed” state).
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

.PARAMETER SourceFolder
Folder containing input videos. Recurses by default.

.PARAMETER SaveFolder
Destination folder for screenshots. Default: <script>\Screenshots

.PARAMETER FramesPerSecond
Approx. capture rate for screenshots (GDI+ mode). Default: 1.

.PARAMETER TimeLimitSeconds
Maximum capture time per video. 0 = unlimited. Default: 0.

.PARAMETER VideoLimit
Maximum number of videos to process this run. 0 = unlimited. Default: 0.

.PARAMETER CropOnly
Skips video playback and runs the Python cropper only.

.PARAMETER ResumeFile
Name or path of a previously saved frame list (or other cropper resume file).
Validated when -CropOnly is used.

.PARAMETER PythonScriptPath
Path to the Python cropper script. Defaults to src\python\crop_colours.py
under the current script folder.

.PARAMETER ProcessedLogPath
Path to the text file tracking processed videos. Default: <script>\processed_videos.log

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
  1.1.10

CHANGELOG
  1.1.10
  - Invoke-Cropper: enforce Python 3.9+ (throws with clear message if lower).
  - New -ClearSnapshotsBeforeRun: when in snapshot mode, delete existing
    <VideoBaseName>_*.png in $SaveFolder before starting each video; sets
    preCount=0 to ensure correct post-run validation.

  1.1.9
  - Add -GdiFullscreen to force legacy full-screen VLC window during GDI+ capture
  - Add -Legacy1080p to capture fixed 1920x1080 region (old method)
  - GDI+ launch now uses GUI interface (no --intf dummy); snapshots still use --intf dummy

  1.1.8
  - Fix: removed custom -Debug switch to avoid name collision with PowerShell’s common -Debug.
    Behavior unchanged for callers: use the common -Debug to enable Write-Debug output.
    Internally, the script now checks $PSBoundParameters.ContainsKey('Debug').
  - Docs: updated notes/examples to mention the common -Debug parameter.

  1.1.7
  - Post-capture: also run crop_colours.py against $SaveFolder when not -CropOnly.
  - (Args: --input <SaveFolder> --skip-bad-images --allow-empty --recurse [+ --resume-file if set])

  1.1.6
  - Invoke-Cropper: call crop_colours.py v3.1.0 with:
      --input <SaveFolder> --skip-bad-images --allow-empty --recurse
    and forward --resume-file when provided.
  - No other changes.

  1.1.5
  - Docs: inline comments clarifying time-limit/loop termination and final $ok conditions.
  - Invoke-Cropper: (previous behavior; superseded by 1.1.6)
  - Minor: keep stdout only in -Debug to avoid “assigned but not used” warnings.

  1.1.4
  - Docs: add full comment-based help to Stop-Vlc and Get-ScreenWithGDIPlus
    (.DESCRIPTION, .PARAMETER, .EXAMPLE) for Get-Help consistency
  - Inline comments: clarify main-loop validation logic (pre/post snapshot counts,
    GDI+ savedThisRun, and final $ok conditions)
  - Behavior: no functional changes; readability and maintainability only

  1.1.3
  - Docs: expand Start-Vlc and Invoke-Cropper help (.DESCRIPTION, .RETURNS, .EXAMPLE)
    and add inline comments for VLC restart strategy and log-creation guard
  - Fix: avoid scoped-variable parse issue by delimiting ${Path} in error message
    inside Add-ContentWithRetry
  - Diagnostics: log first-attempt cropper stderr in Debug on non-zero exit

  1.1.2
  - Robustness: retry appends to processed log (file lock tolerant) and guard
    against truncation by creating the log only if missing
  - GDI+ filenames: prefix saved frames with <VideoBaseName>_ to avoid cross-video
    collisions in shared SaveFolder (parity with VLC snapshot prefix)
  - VLC startup: single restart attempt if VLC exits during the startup window
  - Docs: add comment-based help for Save-FrameWithRetry and Add-ContentWithRetry
    and clarify inline comments (dummy interface, scene-ratio=1, validation gating)

  1.1.1
  - Snapshot mode: per-video --scene-prefix (<VideoBaseName>_) to avoid collisions
  - Post-run validation: ensure frames were actually saved (snapshot pre/post counts; GDI+ counter)
  - Resilience: retry GDI+ frame saves (3 attempts); single retry for Python cropper
  - Preflight: in Crop-only mode, verify Python is in PATH and log version
  - Hygiene: avoid assigning to automatic $args (use $vlcArgs/$pyArgs)

  1.1.0
  - Fix: Time-limit now terminates VLC and prevents false “processed” logging.
  - Fix: VLC is closed/killed on all exit paths via a central finally cleanup.
  - Fix: Non-zero VLC exit codes mark the video as failed (not processed).
  - Add: Parameterised PythonScriptPath; defaults relative to the script root.
  - Add: Validate -ResumeFile in -CropOnly mode.
  - Add: Startup timeout for VLC; improved debug tracing.
  - Add: Optional -UseVlcSnapshots mode (VLC scene filter) to avoid full-screen capture.
  - Doc: Converted to strict comment-based help for Get-Help compatibility.

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

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceFolder = (Join-Path $PSScriptRoot 'videos'),

    [Parameter(Mandatory = $false)]
    [string]$SaveFolder = (Join-Path $PSScriptRoot 'Screenshots'),

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
    [string]$ProcessedLogPath = (Join-Path $PSScriptRoot 'processed_videos.log'),

    [Parameter(Mandatory = $false)]
    [switch]$UseVlcSnapshots,

    [Parameter(Mandatory = $false)]
    [int]$VlcStartupTimeoutSeconds = 10,

    [Parameter(Mandatory = $false)]
    [switch]$GdiFullscreen,

    [Parameter(Mandatory = $false)]
    [switch]$Legacy1080p,

    [Parameter(Mandatory = $false)]
    [switch]$ClearSnapshotsBeforeRun

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
# Create processed log only if missing to avoid truncation
if (-not (Test-Path -LiteralPath $ProcessedLogPath)) {
    New-Item -ItemType File -Path $ProcessedLogPath -Force | Out-Null
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

.PARAMETER VideoPath
Full path to the video file.

.PARAMETER SaveFolder
Destination for snapshot files when -UseVlcSnapshots is enabled.

.PARAMETER UseVlcSnapshots
Enable VLC scene filter snapshots (headless capture, video-frame only).

.EXAMPLE
$proc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\o'
.EXAMPLE
$proc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -SaveFolder 'C:\o' -UseVlcSnapshots
#>
function Start-Vlc {
    param(
        [Parameter(Mandatory)][string]$VideoPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [switch]$UseVlcSnapshots
    )

    # Args that are safe for both modes
    $common = @(
        '--no-qt-privacy-ask',
        '--no-video-title-show',
        '--rate', '1',
        '--play-and-exit'
    )

    $vlcargs = @("`"$VideoPath`"")

    if ($UseVlcSnapshots) {
        # Headless snapshots: no window needed
        $vlcargs += @(
            '--intf', 'dummy',
            '--video-filter=scene',
            "--scene-path=""$SaveFolder""",
            "--scene-prefix=""$([IO.Path]::GetFileNameWithoutExtension($VideoPath))_""",
            '--scene-format=png',
            '--scene-ratio=1'
        )
    } else {
        # GDI+ desktop capture requires a visible window
        if ($GdiFullscreen) {
            $vlcargs += @('--fullscreen', '--video-on-top', '--qt-minimal-view')
        }
        # (no --intf dummy here; we want a GUI window)
    }

    $vlcargs += $common
    Write-Debug ("VLC args: " + ($args -join ' '))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = 'vlc'
    $psi.Arguments = ($args -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $null = $p.Start()

    # Basic startup wait (window may be GUI or dummy)
    $deadline = (Get-Date).AddSeconds($VlcStartupTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($p.HasExited) { break }
        Start-Sleep -Milliseconds 200
    }

    if ($p.HasExited) {
        $stderr = $p.StandardError.ReadToEnd()
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
Invokes crop_colours.py (v3.1.0) with:
  --input <SaveFolder> --skip-bad-images --allow-empty --recurse
and, when provided, --resume-file <ResumeFile> (relative paths resolved under SaveFolder).

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

if ($CropOnly) {
    Write-Message -Level Info -Message "Crop-only mode."
    # Preflight: ensure Python is present and log version for diagnostics
    try {
        $pv = (& python --version) 2>&1
        Write-Debug "Python version: $pv"
    } catch {
        Write-Message -Level Error -Message "Python not found in PATH. Install Python 3.9+ or update PATH."
        exit 1
    }
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
if (Test-Path -LiteralPath $ProcessedLogPath) {
    $processed = Get-Content -LiteralPath $ProcessedLogPath -ErrorAction SilentlyContinue
}

$intervalMs = [int](1000 / [Math]::Max(1, $FramesPerSecond))

foreach ($video in $videos) {
    $already = $processed -contains $video.FullName
    if ($already) {
        Write-Message -Level Info -Message "Skipping (already processed): $($video.FullName)"
        continue
    }

    Write-Message -Level Info -Message "Processing: $($video.FullName)"
    $vlc = $null
    $partial = $false
    $errorDuringCapture = $false
    $started = Get-Date

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
        $vlc = Start-Vlc -VideoPath $video.FullName -SaveFolder $SaveFolder -UseVlcSnapshots:$UseVlcSnapshots
        if (-not $vlc) {
            throw "Failed to start VLC for: $($video.FullName)"
        }

        if ($UseVlcSnapshots) {
            # In snapshot mode we just wait for VLC to finish or time out
            while (-not $vlc.HasExited) {
                # Time-limit guard: mark this run as partial and break.
                # Stop-Vlc in 'finally' will handle process cleanup; later $ok gating
                # ensures we DO NOT mark this video as processed when $partial is $true.
                if ($TimeLimitSeconds -gt 0 -and ((New-TimeSpan -Start $started -End (Get-Date)).TotalSeconds -ge $TimeLimitSeconds)) {
                    Write-Message -Level Warn -Message "Time limit reached; stopping VLC."
                    $partial = $true
                    break
                }
                Start-Sleep -Milliseconds 200
            }
        } else {
            # GDI+ desktop capture loop
            $frameIndex = 0
            $videoBase  = [IO.Path]::GetFileNameWithoutExtension($video.Name)
            while (-not $vlc.HasExited) {
                # Same time-limit semantics as snapshot mode: set $partial and exit loop.
                # Cleanup occurs in finally; outcome gating prevents 'processed' on partial runs.
                if ($TimeLimitSeconds -gt 0 -and ((New-TimeSpan -Start $started -End (Get-Date)).TotalSeconds -ge $TimeLimitSeconds)) {
                    Write-Message -Level Warn -Message "Time limit reached; stopping capture."
                    $partial = $true
                    break
                }

                $filename = ('{0}_{1:D6}.png' -f $videoBase, $frameIndex) # avoid cross-video collisions
                $target   = Join-Path $SaveFolder $filename

                if (Save-FrameWithRetry -TargetPath $target) {
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
        if ($vlc) { Stop-Vlc -Process $vlc }
    }

    # Evaluate outcome
    $vlcExit = if ($vlc) { $vlc.ExitCode } else { -1 }
    Write-Debug "VLC exit code: $vlcExit; partial=$partial; hadErrors=$errorDuringCapture"

    # Post-run validation: ensure frames actually exist
    if ($UseVlcSnapshots) {
        # Compare pre/post counts for this video's prefix
        $postCount = (Get-ChildItem -LiteralPath $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -ErrorAction SilentlyContinue | Measure-Object).Count
        $hadFrames = ($postCount -gt $preCount)
    } else {
        # GDI+: require at least one frame saved during this run
        $hadFrames = ($savedThisRun -gt 0)
    }

    # Final outcome: only mark processed when ALL conditions are true:
    # - not partial (no time-limit break)
    # - no capture errors
    # - VLC exited cleanly (ExitCode 0)
    # - evidence of frames saved (hadFrames)
    $ok = (-not $partial) -and (-not $errorDuringCapture) -and ($vlcExit -eq 0) -and $hadFrames

    if ($ok) {
        if (-not (Add-ContentWithRetry -Path $ProcessedLogPath -Value $video.FullName)) {
            Write-Message -Level Warn -Message "Could not update processed log; leaving video unmarked."
        }
        Write-Message -Level Info -Message "Marked processed: $($video.FullName)"
    } else {
        $reason = if (-not $hadFrames) { 'no frames saved' } elseif ($partial) { 'time limit hit' } elseif ($errorDuringCapture) { 'capture errors' } elseif ($vlcExit -ne 0) { "VLC exit $vlcExit" } else { 'unknown' }
        Write-Message -Level Warn -Message "NOT marked processed ($reason): $($video.FullName)"
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

Write-Message -Level Info -Message "All done."
# endregion Main flow
