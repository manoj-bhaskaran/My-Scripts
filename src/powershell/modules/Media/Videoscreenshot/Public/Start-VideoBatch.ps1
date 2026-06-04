<#
.SYNOPSIS
Entry point for batch video frame capture and optional cropping.

.DESCRIPTION
Runs VLC-based snapshot capture (or GDI capture) over videos discovered under -SourceFolder,
writes frames to -SaveFolder, optionally resumes using processed/resume lists, and can run
the Python cropper over the produced frames. This is the primary public entrypoint; helpers
throw on failure and this function owns user-facing messages.

.PARAMETER SourceFolder
Folder to search for input videos (recursive).
.PARAMETER SaveFolder
Destination for frame files.
.PARAMETER FramesPerSecond
Target FPS for capture (1–60).
.PARAMETER TimeLimitSeconds
Legacy per-video time budget (seconds). Prefer -MaxPerVideoSeconds.
.PARAMETER VideoLimit
Process at most this many videos (0 = no limit).
.PARAMETER ProcessedLogPath
TSV log used for resume/skip; auto-located in SaveFolder when not provided.
.PARAMETER LogFile
Run log file for timestamped module messages. Defaults to a collision-safe
videoscreenshot_<yyyyMMdd_HHmmss>_<RunGuid>.log file under SaveFolder. Pass an
empty string or use -NoLogFile to keep console-only output.
.PARAMETER NoLogFile
Disable the per-run log file while keeping console stream behavior unchanged.
.PARAMETER ResumeFile
Optional file path/name to resume after.
.PARAMETER MaxPerVideoSeconds
Hard cap per video (seconds). Overrides TimeLimitSeconds when > 0.
.PARAMETER StartupGraceSeconds
Extra seconds added to snapshot wait to absorb VLC startup.
.PARAMETER UseVlcSnapshots
Use VLC scene snapshots; otherwise use GDI capture.
.PARAMETER FrameSelection
Frame extraction strategy. Ratio preserves the existing fixed VLC --scene-ratio cadence.
SceneChange uses FFmpeg scene detection when available and falls back to VLC ratio snapshots with a warning when FFmpeg is missing.
.PARAMETER SceneChangeThreshold
FFmpeg scene detection threshold (0.0-1.0) used with -FrameSelection SceneChange.
.PARAMETER GdiFullscreen
With GDI capture, request fullscreen/top-most playback.
.PARAMETER VlcStartupTimeoutSeconds
Timeout for VLC process to initialize.
.PARAMETER VerifyVideos
Opt-in pre-flight that runs Test-VideoPlayable before launching the main VLC session.
Unplayable videos are logged as Skipped/NotPlayable and omitted from later resume runs.
Aliases: -PreflightProbe, -SkipUnplayable.
.PARAMETER VideoProbeTimeoutSeconds
Timeout for the VerifyVideos/Test-VideoPlayable pre-flight probe. Defaults to Config.VideoProbeTimeoutSeconds.
.PARAMETER RunCropper
Run the Python cropper after capture completes.
.PARAMETER CropOnly
Run only the Python cropper over images in -SaveFolder and skip screenshot capture entirely.
.PARAMETER ReprocessCropped
Reprocess files even if they were cropped previously (Python: --reprocess-cropped).
By default, existing crops are deleted and regenerated.
.PARAMETER KeepExistingCrops
When used with -ReprocessCropped, do not delete existing crops; new outputs are added alongside.
.PARAMETER PythonScriptPath
Optional path to the packaged cropper at src/python/media/crop_colours.py.
The path is used to locate src/python; the cropper is still invoked as a
Python module (`python -m media.crop_colours`) so package-relative imports work.
.PARAMETER PythonExe
Python interpreter to use (optional; falls back to py/python in helper).
.PARAMETER ClearSnapshotsBeforeRun
Delete existing frames with the scene prefix before each video.
.PARAMETER VlcExe
Full path to vlc.exe. Use when VLC is not on PATH (e.g. "D:\Program Files\VideoLAN\VLC\vlc.exe").
.PARAMETER NoAudio
Pass --no-audio to VLC. Use when the VLC audio plugin crashes on your system (e.g. libmmdevice_plugin.dll access violation).
.PARAMETER DeduplicateFrames
After each video capture, remove consecutive duplicate frames whose file bytes are identical. One frame per distinct image is kept. Default off; enable for image/slideshow MP4 conversions that produce long runs of identical frames (e.g. picconvert output). Frame counts and status logging reflect the kept frames after de-dup runs.
.PARAMETER RetryUnplayable
Re-attempt previously logged Skipped/NotPlayable videos instead of keeping them in the resume skip set. Use after upgrading from a version that could false-skip playable videos during -VerifyVideos.

.EXAMPLE
Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots -RunCropper -PythonScriptPath .\src\python\media\crop_colours.py
#>
function Start-VideoBatch {
    [CmdletBinding()]
    param(
        [string]$SourceFolder = (Join-Path $PSScriptRoot 'videos'),
        [string]$SaveFolder = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Screenshots'),
        [ValidateRange(1, 60)][int]$FramesPerSecond = 1,
        [int]$TimeLimitSeconds = 0,
        [int]$VideoLimit = 0,

        # Resume, processed logging, and run logging
        [string]$ProcessedLogPath,
        [string]$ResumeFile,
        [AllowEmptyString()]
        [string]$LogFile,
        [switch]$NoLogFile,

        # Advanced timing controls
        [ValidateRange(0, 86400)][int]$MaxPerVideoSeconds = 0,
        [ValidateRange(0, 60)][int]$StartupGraceSeconds = 2,

        [switch]$UseVlcSnapshots,
        [ValidateSet('Ratio', 'SceneChange')]
        [string]$FrameSelection = 'Ratio',
        [ValidateRange(0, 1)]
        [double]$SceneChangeThreshold = 0.35,
        [switch]$GdiFullscreen,
        [int]$VlcStartupTimeoutSeconds = 10,
        # Optional validation / discovery flexibility
        [Alias('PreflightProbe', 'SkipUnplayable')]
        [switch]$VerifyVideos,
        [ValidateRange(0, 300)][int]$VideoProbeTimeoutSeconds = 0,
        [string[]]$IncludeExtensions,

        # Pipeline completion parameters
        [switch]$RunCropper,
        [switch]$CropOnly,
        [switch]$ReprocessCropped,
        [switch]$KeepExistingCrops,
        [string]$PythonScriptPath,
        [string]$PythonExe,
        [switch]$NoAutoInstall,
        [switch]$ClearSnapshotsBeforeRun,

        [string]$VlcExe,
        [switch]$NoAudio,
        [switch]$DeduplicateFrames,
        [switch]$RetryUnplayable
    )

    # Enforce pwsh 7+ at runtime (friendly error if invoked directly)
    Assert-Pwsh7OrThrow

    # Policy: helpers throw; only this function emits user-facing messages.
    $runGuid = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $context = New-VideoRunContext -RequestedFps $FramesPerSecond -SaveFolder $SaveFolder -RunGuid $runGuid
    if (-not $PSBoundParameters.ContainsKey('FrameSelection') -and $context.Config -and $context.Config.FrameSelection) {
        $FrameSelection = [string]$context.Config.FrameSelection
    }
    if (-not $PSBoundParameters.ContainsKey('SceneChangeThreshold') -and $context.Config -and $context.Config.SceneChange -and $null -ne $context.Config.SceneChange.Threshold) {
        $SceneChangeThreshold = [double]$context.Config.SceneChange.Threshold
    }
    $useSceneChange = ($FrameSelection -eq 'SceneChange')
    $sceneChangeBackend = 'ffmpeg'
    if ($context.Config -and $context.Config.SceneChange -and -not [string]::IsNullOrWhiteSpace([string]$context.Config.SceneChange.Backend)) {
        $sceneChangeBackend = ([string]$context.Config.SceneChange.Backend).ToLowerInvariant()
    }
    if ($useSceneChange) { $UseVlcSnapshots = $true }
    $mode = ($CropOnly ? 'Crop-only' : ($useSceneChange ? 'Scene-change snapshots' : ($UseVlcSnapshots ? 'VLC snapshots' : 'GDI+ desktop')))

    if ($CropOnly -and -not $PSBoundParameters.ContainsKey('SaveFolder')) {
        throw "CropOnly requires -SaveFolder pointing to the folder containing images to crop."
    }
    if ($CropOnly -and -not (Test-Path -LiteralPath $SaveFolder -PathType Container)) {
        throw "SaveFolder not found (CropOnly expects images here): $SaveFolder"
    }

    # Validate/create SaveFolder before resolving the default run log path. This
    # also makes the CropOnly fast-path log-capable before it emits messages.
    if (-not (Test-FolderWritable -Path $SaveFolder)) {
        throw "SaveFolder is not writable or could not be created: $SaveFolder"
    }

    $logFileExplicitlyProvided = $PSBoundParameters.ContainsKey('LogFile')
    $resolvedRunLogFile = Initialize-RunLogFile `
        -SaveFolder $SaveFolder `
        -RunGuid $runGuid `
        -LogFile $LogFile `
        -LogFileExplicitlyProvided $logFileExplicitlyProvided `
        -NoLogFile:$NoLogFile

    try {
    # Context contains Version, Config (defaults incl. VideoExtensions), RunGuid, SaveFolder, RequestedFps
    Write-Message -Level Info -Message ("videoscreenshot module v{0} starting (Mode={1}, FPS={2}, SaveFolder=""{3}"")" -f ($context.Version -as [string]), $mode, $FramesPerSecond, $SaveFolder)
    if (-not [string]::IsNullOrWhiteSpace($resolvedRunLogFile)) {
        Write-Message -Level Info -Message ("Run log file: {0}" -f $resolvedRunLogFile)
    }

    # --- Crop-only fast path ---------------------------------------------------
    if ($CropOnly) {
        $captureParams = @('SourceFolder', 'UseVlcSnapshots', 'FramesPerSecond', 'TimeLimitSeconds', 'MaxPerVideoSeconds',
            'GdiFullscreen', 'VlcStartupTimeoutSeconds', 'VerifyVideos', 'VideoProbeTimeoutSeconds', 'IncludeExtensions',
            'FrameSelection', 'SceneChangeThreshold', 'ClearSnapshotsBeforeRun', 'VideoLimit', 'ResumeFile', 'ProcessedLogPath', 'RetryUnplayable')
        $ignored = @($captureParams | Where-Object { $PSBoundParameters.ContainsKey($_) })
        $isDebug = $PSBoundParameters.ContainsKey('Debug')
        Invoke-CropOnlyMode `
            -SaveFolder $SaveFolder `
            -PythonScriptPath $PythonScriptPath `
            -PythonExe $PythonExe `
            -NoAutoInstall:$NoAutoInstall `
            -ReprocessCropped:$ReprocessCropped `
            -KeepExistingCrops:$KeepExistingCrops `
            -IsDebug $isDebug `
            -ModuleVersion ($context.Version -as [string]) `
            -IgnoredParams $ignored
        Write-Debug 'TRACE Start-VideoBatch: leaving (CropOnly)'
        return
    }

    # Optional cropper pre-validation (fail fast with clear diagnostics)
    if ($RunCropper) {
        Assert-PythonCropperReady -PythonScriptPath $PythonScriptPath -PythonExe $PythonExe
    }

    if (-not (Test-Path -LiteralPath $SourceFolder)) {
        Write-Message -Level Error -Message "SourceFolder not found: $SourceFolder"
        throw "Invalid SourceFolder."
    }
    $resolvedFfmpegExe = $null
    if ($useSceneChange) {
        if ($sceneChangeBackend -eq 'ffmpeg') {
            if (Get-Command Get-FfmpegCommand -ErrorAction SilentlyContinue) {
                $resolvedFfmpegExe = Get-FfmpegCommand
            }
            else {
                try { $resolvedFfmpegExe = (Get-Command ffmpeg -ErrorAction Stop).Source } catch { $resolvedFfmpegExe = $null }
            }
            if ([string]::IsNullOrWhiteSpace($resolvedFfmpegExe)) {
                Write-Message -Level Warn -Message "FrameSelection=SceneChange requested but ffmpeg was not found on PATH; falling back to VLC --scene-ratio snapshots."
            }
            else {
                Write-Message -Level Info -Message ("FrameSelection=SceneChange using ffmpeg backend (threshold={0})" -f $SceneChangeThreshold)
            }
        }
        else {
            Write-Message -Level Warn -Message ("FrameSelection=SceneChange backend '{0}' is not available; falling back to VLC --scene-ratio snapshots." -f $sceneChangeBackend)
        }
    }

    $requiresVlc = $VerifyVideos -or (-not $useSceneChange) -or [string]::IsNullOrWhiteSpace($resolvedFfmpegExe)
    $resolvedVlcExe = $null
    if ($requiresVlc) {
        $resolvedVlcExe = Resolve-VlcExecutable -VlcExe $VlcExe
    }
    # Resolve processed log path and build resume set
    $processedLog = if ([string]::IsNullOrWhiteSpace($ProcessedLogPath)) {
        Join-Path $SaveFolder '.processed_videos.txt'
    }
    else {
        $ProcessedLogPath
    }
    $processedSet = Get-ProcessedVideoSet -ProcessedLogPath $processedLog -ResumeFile $ResumeFile -RetryUnplayable:$RetryUnplayable
    Write-Debug ("Resume/processed set: Type={0}; Count={1}; Log={2}" -f $processedSet.GetType().FullName, $processedSet.Count, $processedLog)
    if ($processedSet.Count -gt 0) {
        Write-Message -Level Info -Message ("Resume enabled: {0} item(s) will be skipped based on processed/resume lists." -f $processedSet.Count)
    }

    $probeTimeoutSeconds = if ($VideoProbeTimeoutSeconds -gt 0) {
        $VideoProbeTimeoutSeconds
    }
    else {
        [Math]::Max(1, [int]$context.Config.VideoProbeTimeoutSeconds)
    }

    # If requested, verify videos only when a verifier is available
    $canVerify = $false
    if ($VerifyVideos) {
        if (Test-CommandAvailable -CommandName 'Test-VideoPlayable') {
            $canVerify = $true
        }
        else {
            Write-Message -Level Warn -Message "VerifyVideos requested but Test-VideoPlayable is not available; skipping verification."
            $canVerify = $false
        }
    }

    # Initialize PID registry for this run
    $pidFile = Initialize-PidRegistry -Context $context -SaveFolder $SaveFolder -RunGuid $runGuid
    Write-Debug "PID registry: $pidFile"

    # Initialize VLC's own sidecar logfile. This avoids redirecting stdout/stderr
    # pipes for the long-running process, which can deadlock when VLC is chatty.
    $vlcLogFile = Initialize-VlcSidecarLog -Context $context -SaveFolder $SaveFolder -RunGuid $runGuid

    # Discover videos (configurable extension set via param or config)
    $exts = if ($IncludeExtensions -and $IncludeExtensions.Count -gt 0) { $IncludeExtensions } else { $context.Config.VideoExtensions }
    $patterns = $exts | ForEach-Object {
        $e = $_.Trim()
        if ($e -notmatch '^\.') { $e = '.' + $e }
        '*{0}' -f $e
    }
    $videos = Get-ChildItem -Path (Join-Path $SourceFolder '*') -Recurse -File -Include $patterns
    if (-not $videos) {
        Write-Message -Level Warn -Message "No videos found under $SourceFolder."
        Remove-TempRunFile -Path $pidFile -Label 'PID registry'
        Remove-TempRunFile -Path $vlcLogFile -Label 'VLC sidecar log'
        $null = Write-Message -Level Info -Message ("videoscreenshot module v{0} finished — processed 0 file(s)" -f ($context.Version))
        return
    }

    $processedCount = 0
    $attemptedCount = 0
    $retainVlcLog = $false

    foreach ($video in $videos) {
        if ($VideoLimit -gt 0 -and $attemptedCount -ge $VideoLimit) { break }

        # Skip if already processed / per resume list
        $normPath = Resolve-VideoPath -Path $video.FullName
        if ($processedSet.Contains($normPath)) {
            Write-Debug "Skipping already processed: $normPath"
            continue
        }

        # Optional: verify video playability before spending time on it
        if ($canVerify) {
            try {
                if (-not (Test-VideoPlayable -Path $video.FullName -VlcExe $resolvedVlcExe -TimeoutSeconds $probeTimeoutSeconds)) {
                    Write-Message -Level Warn -Message ("Skipping not-playable video: {0}" -f $video.FullName)
                    $null = Write-ProcessedLog -Path $processedLog -VideoPath $video.FullName -Status 'Skipped' -Reason 'NotPlayable'
                    continue
                }
            }
            catch {
                Write-Message -Level Warn -Message ("Video verification error for {0}: {1}" -f $video.FullName, $_.Exception.Message)
                $null = Write-ProcessedLog -Path $processedLog -VideoPath $video.FullName -Status 'Skipped' -Reason 'VideoProbeError'
                continue
            }
        }

        $attemptedCount++

        $scenePrefix = ('{0}_' -f [IO.Path]::GetFileNameWithoutExtension($video.Name))

        if ($ClearSnapshotsBeforeRun) {
            # Best-effort clean-up of prior runs for this video
            Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        $preCount = (Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count

        $p = $null
        $snapStats = $null
        $gdiStats = $null
        $processingFailed = $false
        $processingError = $null

        # Compute the per-video cap:
        # Prefer MaxPerVideoSeconds (explicit) over TimeLimitSeconds (legacy).
        $capSeconds = if ($MaxPerVideoSeconds -gt 0) { [int]$MaxPerVideoSeconds }
        elseif ($TimeLimitSeconds -gt 0) { [int]$TimeLimitSeconds }
        else { 0 }
        $stopAfter = [double]$capSeconds

        try {
            $baseWait = $null
            if ($UseVlcSnapshots) {
                $baseWait = if ($capSeconds -gt 0) {
                    [int]$capSeconds
                } else {
                    $detectedDuration = Get-VideoDuration -Path $video.FullName
                    if ($detectedDuration -gt 0) {
                        $grace = [int]$context.Config.SnapshotDurationGraceSeconds
                        $slackFactor = [double]$context.Config.SnapshotDurationSlackFactor
                        if ($slackFactor -le 0) { $slackFactor = 2.0 }
                        $floorSeconds = [int]$context.Config.SnapshotMinimumTimeoutSeconds
                        if ($floorSeconds -lt 1) { $floorSeconds = 1 }
                        $slackSeconds = [Math]::Ceiling([double]$detectedDuration * $slackFactor)
                        [int][Math]::Ceiling([Math]::Max($slackSeconds, $floorSeconds) + $grace)
                    } else {
                        Write-Debug ("Duration probe failed for '{0}'; using flat fallback ({1} s)." -f $video.FullName, $context.Config.SnapshotFallbackTimeoutSeconds)
                        [int]$context.Config.SnapshotFallbackTimeoutSeconds
                    }
                }
                $waitSeconds = [int]([Math]::Max(1, $baseWait + [int]$StartupGraceSeconds))

                if ($useSceneChange -and -not [string]::IsNullOrWhiteSpace($resolvedFfmpegExe)) {
                    $includeFirstFrame = $true
                    $ffmpegBaseArgs = @('-hide_banner', '-loglevel', 'error', '-nostdin', '-y')
                    if ($context.Config.SceneChange) {
                        if ($null -ne $context.Config.SceneChange.IncludeFirstFrame) { $includeFirstFrame = [bool]$context.Config.SceneChange.IncludeFirstFrame }
                        if ($context.Config.SceneChange.FfmpegArgs) { $ffmpegBaseArgs = [string[]]$context.Config.SceneChange.FfmpegArgs }
                    }
                    Write-Debug ("TRACE Start-VideoBatch: about to call Invoke-FfmpegSceneChangeCapture (MaxSeconds={0}, Prefix={1}, Threshold={2})" -f $waitSeconds, $scenePrefix, $SceneChangeThreshold)
                    $snapStats = Invoke-FfmpegSceneChangeCapture `
                        -FfmpegExe $resolvedFfmpegExe `
                        -VideoPath $video.FullName `
                        -SaveFolder $SaveFolder `
                        -ScenePrefix $scenePrefix `
                        -Threshold $SceneChangeThreshold `
                        -StopAtSeconds $stopAfter `
                        -TimeoutSeconds $waitSeconds `
                        -IncludeFirstFrame $includeFirstFrame `
                        -BaseArgs $ffmpegBaseArgs
                    $snapType = if ($null -ne $snapStats) { $snapStats.GetType().FullName } else { '<null>' }
                    $snapStr = if ($null -ne $snapStats) { $snapStats.ToString() } else { '<null>' }
                    Write-Debug ("TRACE Start-VideoBatch: Invoke-FfmpegSceneChangeCapture returned type={0} tostring={1}" -f $snapType, $snapStr)
                }
                else {
                    $p = Start-Vlc -Context $context `
                        -VideoPath $video.FullName `
                        -SaveFolder $SaveFolder `
                        -UseVlcSnapshots:$UseVlcSnapshots `
                        -RequestedFps $FramesPerSecond `
                        -StopAtSeconds $stopAfter `
                        -GdiFullscreen:$GdiFullscreen `
                        -StartupTimeoutSeconds $VlcStartupTimeoutSeconds `
                        -VlcExe $resolvedVlcExe `
                        -NoAudio:$NoAudio

                    Write-Debug ("TRACE Start-VideoBatch: about to call Wait-ForSnapshotFrames (MaxSeconds={0}, Prefix={1}, CapSeconds={2})" -f $waitSeconds, $scenePrefix, $capSeconds)
                    $snapStats = Wait-ForSnapshotFrames -SaveFolder $SaveFolder -ScenePrefix $scenePrefix -MaxSeconds $waitSeconds -Process $p `
                        -IdleTimeoutSeconds ([int]$context.Config.SnapshotIdleTimeoutSeconds) `
                        -WarmUpSeconds ([int]$context.Config.SnapshotIdleWarmUpSeconds)
                    $snapType = if ($null -ne $snapStats) { $snapStats.GetType().FullName } else { '<null>' }
                    $snapStr = if ($null -ne $snapStats) { $snapStats.ToString() } else { '<null>' }
                    Write-Debug ("TRACE Start-VideoBatch: Wait-ForSnapshotFrames returned type={0} tostring={1}" -f $snapType, $snapStr)
                    if ($null -ne $snapStats -and $snapStats.HitMaxSeconds -and $snapStats.ProcessAliveAtExit) {
                        $retainVlcLog = $true
                        Write-Message -Level Warn -Message ("VLC snapshot cap hit while playback was still active for: {0}; marking as timeout/truncation so resume can retry." -f $video.FullName)
                    }
                }
            }
            else {
                $p = Start-Vlc -Context $context `
                    -VideoPath $video.FullName `
                    -SaveFolder $SaveFolder `
                    -UseVlcSnapshots:$UseVlcSnapshots `
                    -RequestedFps $FramesPerSecond `
                    -StopAtSeconds $stopAfter `
                    -GdiFullscreen:$GdiFullscreen `
                    -StartupTimeoutSeconds $VlcStartupTimeoutSeconds `
                    -VlcExe $resolvedVlcExe `
                    -NoAudio:$NoAudio

                $dur = if ($capSeconds -gt 0) { [int]$capSeconds } else { [int]$context.Config.GdiCaptureDefaultSeconds }
                Write-Debug ("TRACE Start-VideoBatch: about to call Invoke-GdiCapture (DurationSeconds={0}, FPS={1}, Prefix={2})" -f $dur, $FramesPerSecond, $scenePrefix)
                $gdiStats = Invoke-GdiCapture -DurationSeconds $dur -Fps $FramesPerSecond -SaveFolder $SaveFolder -ScenePrefix $scenePrefix
                $gdiType = if ($null -ne $gdiStats) { $gdiStats.GetType().FullName } else { '<null>' }
                $gdiStr = if ($null -ne $gdiStats) { $gdiStats.ToString() } else { '<null>' }
                Write-Debug ("TRACE Start-VideoBatch: Invoke-GdiCapture returned type={0} tostring={1}" -f $gdiType, $gdiStr)
            }
        }
        catch {
            $processingFailed = $true
            $retainVlcLog = $true
            $processingError = $_.Exception.Message
            Write-Message -Level Error -Message ("Processing failed for: {0} — {1}" -f $video.FullName, $processingError)
        }
        finally {
            if ($p) {
                $__stop = Stop-Vlc -Context $context -Process $p
                $__stopType = if ($null -ne $__stop) { $__stop.GetType().FullName } else { '<null>' }
                Write-Debug ("TRACE Start-VideoBatch: Stop-Vlc returned type={0}" -f $__stopType)
                $null = $__stop

                $__unreg = Unregister-RunPid -Context $context -ProcessId $p.Id
                $__unregType = if ($null -ne $__unreg) { $__unreg.GetType().FullName } else { '<null>' }
                $__unregStr = if ($null -ne $__unreg) { $__unreg.ToString() } else { '<null>' }
                Write-Debug ("TRACE Start-VideoBatch: Unregister-RunPid returned type={0} tostring={1}" -f $__unregType, $__unregStr)
                $null = $__unreg
            }
        }

        # De-duplicate consecutive identical frames if requested.
        # Preliminary delta for dedup gating: avoids running dedup on a zero-capture
        # run (e.g. VLC produced nothing), which would de-dup pre-existing frames from
        # a previous run on the same prefix.
        $dedupStats = $null
        if ($DeduplicateFrames -and -not $processingFailed) {
            $_prelimDelta = 0
            if ($UseVlcSnapshots) {
                if ($null -ne $snapStats) { $_prelimDelta = [int]$snapStats.FramesDelta }
                else {
                    $_prelimDelta = [int]((Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count - $preCount)
                }
            }
            else {
                if ($null -ne $gdiStats) { $_prelimDelta = [int]$gdiStats.FramesSaved }
                else {
                    $_prelimDelta = [int]((Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count - $preCount)
                }
            }
            if ($_prelimDelta -gt 0) {
                $dedupAlgorithm = if ($context.Config.ContainsKey('DeduplicateHashAlgorithm')) {
                    [string]$context.Config.DeduplicateHashAlgorithm
                } else { 'SHA256' }
                try {
                    $dedupStats = Invoke-SnapshotDedup -SaveFolder $SaveFolder -ScenePrefix $scenePrefix -HashAlgorithm $dedupAlgorithm
                    Write-Debug ("Snapshot.Dedup: removed {0}/{1} frame(s) for prefix '{2}'" -f $dedupStats.RemovedCount, $dedupStats.OriginalCount, $scenePrefix)
                    if ($dedupStats.RemovedCount -gt 0) {
                        Write-Message -Level Info -Message ("De-dup: removed {0} duplicate frame(s) for '{1}' ({2} unique frame(s) kept)" -f $dedupStats.RemovedCount, $scenePrefix, $dedupStats.KeptCount)
                    }
                }
                catch {
                    Write-Message -Level Warn -Message ("De-dup failed for prefix '{0}': {1}" -f $scenePrefix, $_.Exception.Message)
                }
            }
        }

        # Compute final frame delta and achieved FPS from stats, disk fallback, and dedup reconciliation.
        $metrics = Measure-CaptureFrameDelta `
            -SnapStats $snapStats `
            -GdiStats $gdiStats `
            -DedupStats $dedupStats `
            -PreCount $preCount `
            -ScenePrefix $scenePrefix `
            -SaveFolder $SaveFolder `
            -UseVlcSnapshots:$UseVlcSnapshots
        $framesDelta = $metrics.FramesDelta
        $achievedFps = $metrics.AchievedFps

        # Determine status and log the video as processed
        if ($processingFailed) {
            # Failed rows remain retry-eligible on subsequent resume runs.
            $null = Write-ProcessedLog -Path $processedLog -VideoPath $video.FullName -Status 'Failed' -Reason $processingError
            Write-Message -Level Warn -Message ("Video marked as failed (eligible for retry on resume): {0}" -f $video.FullName)
        }
        elseif ($framesDelta -le 0) {
            Write-Message -Level Warn -Message ("No frames produced for: {0}" -f $video.FullName)
            # Log zero-frame captures as failed so resume runs can retry them.
            $null = Write-ProcessedLog -Path $processedLog -VideoPath $video.FullName -Status 'Failed' -Reason 'NoFrames'
        }
        elseif ($UseVlcSnapshots -and $null -ne $snapStats -and $snapStats.HitMaxSeconds -and $snapStats.ProcessAliveAtExit) {
            # Some frames were produced, but the safety-net cap interrupted a live VLC session.
            # Keep the row retry-eligible for status-aware resume.
            $null = Write-ProcessedLog -Path $processedLog -VideoPath $video.FullName -Status 'TimedOutProcessed' -Reason 'SnapshotCapHit'
            Write-Message -Level Warn -Message ("Video marked as timed out/truncated (eligible for retry on resume): {0}" -f $video.FullName)
        }
        else {
            if ($null -ne $achievedFps) {
                Write-Message -Level Info -Message ("Frames saved: {0} (prefix {1}); achieved FPS: {2}" -f $framesDelta, $scenePrefix, $achievedFps)
            }
            else {
                Write-Message -Level Info -Message ("Frames saved: {0} (prefix {1})" -f $framesDelta, $scenePrefix)
            }

            # Append processed on success
            $null = Write-ProcessedLog -Path $processedLog -VideoPath $video.FullName -Status 'Processed'
            $processedCount++
        }
    }
    # After capture, optionally run the cropper once over the output images (SaveFolder)
    if ($RunCropper) {
        try {
            $isDebug = $PSBoundParameters.ContainsKey('Debug')
            $crop = Invoke-Cropper `
                -PythonScriptPath $PythonScriptPath `
                -PythonExe $PythonExe `
                -InputFolder $SaveFolder `
                -NoAutoInstall:$NoAutoInstall `
                -ReprocessCropped:$ReprocessCropped `
                -KeepExistingCrops:$KeepExistingCrops `
                -Debug:$isDebug
            Write-Message -Level Info -Message ("Cropper finished OK (exit={0}). STDERR: {1}" -f $crop.ExitCode, ([string]::IsNullOrWhiteSpace($crop.StdErr) ? '<none>' : $crop.StdErr))
        }
        catch {
            # Include as much context as we have
            Write-Message -Level Warn -Message ("Cropper failed: {0}" -f $_.Exception.Message)
        }
    }

    # Clean up the PID registry file created for this run
    Remove-TempRunFile -Path $pidFile -Label 'PID registry'

    # Clean VLC's sidecar logfile on successful runs; retain it deterministically
    # when processing failed so startup/decoder diagnostics remain available.
    if ($retainVlcLog) {
        if (-not [string]::IsNullOrWhiteSpace($vlcLogFile)) {
            Write-Message -Level Warn -Message ("Retaining VLC sidecar log after failure: {0}" -f $vlcLogFile)
        }
    }
    else {
        Remove-TempRunFile -Path $vlcLogFile -Label 'VLC sidecar log'
    }

    $null = Write-Message -Level Info -Message ("videoscreenshot module v{0} finished — processed {1} file(s)" -f ($context.Version), $processedCount)
    Write-Debug 'TRACE Start-VideoBatch: leaving (no output intended)'
    return
    }
    finally {
        Clear-VideoScreenshotLogFile
    }
}
