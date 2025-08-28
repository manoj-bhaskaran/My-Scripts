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

.PARAMETER Debug
Enables verbose debug tracing via Write-Debug.

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

.NOTES
AUTHOR
  Manoj Bhaskaran

VERSION
  1.1.2

CHANGELOG
  1.1.2
  - Robustness: retry appends to processed log (file lock tolerant) and guard
    against truncation by creating the log only if missing
  - GDI+ filenames: prefix saved frames with <VideoBaseName>_ to avoid cross-video
    collisions in shared SaveFolder (parity with VLC snapshot prefix)
  - VLC startup: single restart attempt if VLC exits during the startup window
  - Docs: add comment-based help for Save-FrameWithRetry and clarify inline
    comments (dummy interface, scene-ratio=1, validation gating)

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
    [switch]$Debug,

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
    [int]$VlcStartupTimeoutSeconds = 10
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

# Expand debug preference if requested
if ($Debug) { $DebugPreference = 'Continue' }

# Load assemblies needed for GDI+ capture (PS7 on Windows supports System.Drawing)
Add-Type -AssemblyName System.Drawing | Out-Null
Add-Type -AssemblyName System.Windows.Forms | Out-Null

<#
.SYNOPSIS
Retries saving a frame to disk to absorb transient I/O errors.
.DESCRIPTION
Calls Get-ScreenWithGDIPlus up to MaxAttempts, backing off between tries.
Returns $true on success, $false after exhausting retries.
.PARAMETER TargetPath
Full path of the PNG to write.
.PARAMETER MaxAttempts
Maximum attempts (default 3).
.EXAMPLE
Save-FrameWithRetry -TargetPath (Join-Path $SaveFolder 'frame_000001.png') -MaxAttempts 3
#>
function Save-FrameWithRetry {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [int]$MaxAttempts = 3
    )
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            Get-ScreenWithGDIPlus -TargetPath $TargetPath
            return $true
        } catch {
            if ($i -eq $MaxAttempts) {
                Write-Message -Level Error -Message "Failed to save frame after $MaxAttempts attempts: $($_.Exception.Message)"
                return $false
            }
            Start-Sleep -Milliseconds (200 * $i)  # simple linear backoff
        }
    }
}

# endregion Utilities

# region Capture helpers

<#
.SYNOPSIS
Start VLC for a single video file.
.DESCRIPTION
Launches vlc.exe with suitable flags for either GDI+ capture or snapshot mode.
.NOTES
Uses `--intf dummy` (no GUI) for low overhead. In snapshot mode, `--scene-ratio=1`
requests a snapshot for every rendered frame; this can produce many files. Use
-TimeLimitSeconds and sufficient free space.
.PARAMETER VideoPath
Full path to the video file.
.PARAMETER UseVlcSnapshots
Switch to enable VLC scene filter snapshots.
.PARAMETER SaveFolder
Folder where VLC should write snapshots when snapshot mode is enabled.
.EXAMPLE
$proc = Start-Vlc -VideoPath 'C:\v\clip.mp4' -UseVlcSnapshots -SaveFolder 'C:\o'
#>
function Start-Vlc {
    param(
        [Parameter(Mandatory)][string]$VideoPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [switch]$UseVlcSnapshots
    )

    $commonArgs = @(
        '--intf', 'dummy',           # headless interface (no GUI window)
        '--no-qt-privacy-ask',
        '--no-video-title-show',
        '--rate', '1',
        '--play-and-exit'
    )

    $snapshotArgs = @()
    if ($UseVlcSnapshots) {
        # scene-ratio uses frame ratio, not seconds. ratio=1 requests every frame.
        # Use a per-video prefix to avoid collisions across videos/runs.
        $snapshotArgs = @(
            '--video-filter=scene',
            "--scene-path=`"$SaveFolder`"",
            "--scene-prefix=`"$([IO.Path]::GetFileNameWithoutExtension($VideoPath))_`"",
            '--scene-format=png',
            '--scene-ratio=1'
            )
    }

    $vlcArgs = @()
    $vlcArgs += "`"$VideoPath`""
    $vlcArgs += $commonArgs
    $vlcArgs += $snapshotArgs
    Write-Debug ("VLC args: " + ($vlcArgs -join ' '))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = 'vlc'
    $psi.Arguments = ($vlcArgs -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $null = $p.Start()

    # Wait for non-exited state as a minimal startup confirmation
    $deadline = (Get-Date).AddSeconds($VlcStartupTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($p.HasExited) { break }
        Start-Sleep -Milliseconds 200
        # With --intf dummy, no window is created; we rely on the process not exiting.
    }

    # If VLC exited during startup, try a single restart to handle sporadic start failures
    if ($p.HasExited) {
        Write-Debug "VLC exited during startup; retrying once…"
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        try { $null = $p.Start() } catch {}
        $deadline = (Get-Date).AddSeconds($VlcStartupTimeoutSeconds)
        while ((Get-Date) -lt $deadline) {
            if ($p.HasExited) { break }
            Start-Sleep -Milliseconds 200
        }
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
Attempts CloseMainWindow, waits briefly, then Stop-Process -Force if still running.
.PARAMETER Process
The VLC process object.
.EXAMPLE
Stop-Vlc -Process $proc
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
Captures the entire primary screen to a PNG file.
.DESCRIPTION
Uses System.Drawing to copy from the primary screen and saves to disk.
.PARAMETER TargetPath
Full path of the PNG file to write.
.EXAMPLE
Get-ScreenWithGDIPlus -TargetPath 'C:\shots\frame_0001.png'
#>
function Get-ScreenWithGDIPlus {
    param(
        [Parameter(Mandatory)][string]$TargetPath
    )
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bmp.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

<#
.SYNOPSIS
Runs the external Python cropper script.
.DESCRIPTION
Invokes Python with the given cropper path, passing SaveFolder and optional resume file.
.PARAMETER PythonScriptPath
Path to the Python script.
.PARAMETER SaveFolder
Folder containing images to be processed.
.PARAMETER ResumeFile
Optional resume file path or name (if relative, resolved under SaveFolder).
.EXAMPLE
Invoke-Cropper -PythonScriptPath .\crop_colours.py -SaveFolder .\Screenshots
#>
function Invoke-Cropper {
    param(
        [Parameter(Mandatory)][string]$PythonScriptPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [string]$ResumeFile
    )

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
        $resumeArg = @('--resume_file', "`"$resumePath`"")
    }

    $pyArgs = @("`"$PythonScriptPath`"", '--input', "`"$SaveFolder`"") + $resumeArg
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
    # Read stdout only when Debug is active; otherwise discard to avoid unused-variable warnings
    if ($DebugPreference -eq 'Continue') {
        $cropperStdout = $p.StandardOutput.ReadToEnd()
    } else {
        $null = $p.StandardOutput.ReadToEnd()
    }
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($p.ExitCode -ne 0) {
        $stderr = $p.StandardError.ReadToEnd()
        if ($DebugPreference -eq 'Continue' -and $stderr) { Write-Debug "Cropper stderr (first attempt):`n$stderr" }
         # One lightweight retry to handle transient issues (e.g., file locks)
         Start-Sleep -Milliseconds 500
         $p2 = New-Object System.Diagnostics.Process
         $p2.StartInfo = $psi
         $null = $p2.Start()
         if ($DebugPreference -eq 'Continue') {
             $cropperStdout2 = $p2.StandardOutput.ReadToEnd()
         } else {
             $null = $p2.StandardOutput.ReadToEnd()
         }
         $stderr2 = $p2.StandardError.ReadToEnd()
         $p2.WaitForExit()
         if ($p2.ExitCode -ne 0) {
             Write-Message -Level Error -Message "Cropper failed (ExitCode=$($p2.ExitCode)). $stderr2"
             throw "Cropper failed."
         } else {
             if ($DebugPreference -eq 'Continue') { Write-Debug "Cropper (retry) output:`n$cropperStdout2" }
             Write-Message -Level Info -Message "Cropper finished successfully (after retry)."
             $null = $p.StandardError.ReadToEnd()
         }
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
        # Count existing snapshots for this video's prefix before starting
        $preCount = (Get-ChildItem -LiteralPath $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -ErrorAction SilentlyContinue | Measure-Object).Count
    }

    try {
        $vlc = Start-Vlc -VideoPath $video.FullName -SaveFolder $SaveFolder -UseVlcSnapshots:$UseVlcSnapshots
        if (-not $vlc) {
            throw "Failed to start VLC for: $($video.FullName)"
        }

        if ($UseVlcSnapshots) {
            # In snapshot mode we just wait for VLC to finish or time out
            while (-not $vlc.HasExited) {
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
        $postCount = (Get-ChildItem -LiteralPath $SaveFolder -Filter "$scenePrefixForThisVideo*.png" -ErrorAction SilentlyContinue | Measure-Object).Count
        $hadFrames = ($postCount -gt $preCount)
    } else {
        $hadFrames = ($savedThisRun -gt 0)
    }

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

Write-Message -Level Info -Message "All done."
# endregion Main flow
