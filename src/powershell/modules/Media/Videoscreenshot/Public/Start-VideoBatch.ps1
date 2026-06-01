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
        [switch]$DeduplicateFrames
    )

    # Enforce pwsh 7+ at runtime (friendly error if invoked directly)
    Assert-Pwsh7OrThrow

    # Policy: helpers throw; only this function emits user-facing messages.
    $mode = ($CropOnly ? 'Crop-only' : ($UseVlcSnapshots ? 'VLC snapshots' : 'GDI+ desktop'))
    $runGuid = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $context = New-VideoRunContext -RequestedFps $FramesPerSecond -SaveFolder $SaveFolder -RunGuid $runGuid

    if ($CropOnly -and -not $PSBoundParameters.ContainsKey('SaveFolder')) {
        throw "CropOnly requires -SaveFolder pointing to the folder containing images to crop."
    }
    if ($CropOnly -and -not (Test-Path -LiteralPath $SaveFolder -PathType Container)) {
        throw "SaveFolder not found (CropOnly expects images here): $SaveFolder"
    }

    # Validate/create SaveFolder before resolving the default run log path. This
    # also makes the CropOnly fast-path log-capable before it emits messages.
    Test-FolderWritable -Folder $SaveFolder | Out-Null

    $resolvedRunLogFile = $null
    $logFileExplicitlyProvided = $PSBoundParameters.ContainsKey('LogFile')
    if (-not $NoLogFile -and -not ($logFileExplicitlyProvided -and [string]::IsNullOrWhiteSpace($LogFile))) {
        $resolvedRunLogFile = if ($logFileExplicitlyProvided) {
            $LogFile
        }
        else {
            Join-Path $SaveFolder ("videoscreenshot_{0}_{1}.log" -f (Get-Date).ToString('yyyyMMdd_HHmmss'), $runGuid)
        }

        $runLogParent = Split-Path -Path $resolvedRunLogFile -Parent
        if (-not [string]::IsNullOrWhiteSpace($runLogParent) -and -not (Test-Path -LiteralPath $runLogParent -PathType Container)) {
            try {
                New-Item -ItemType Directory -Path $runLogParent -Force -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning ("Unable to create run log directory '{0}': {1}. File logging will remain best-effort." -f $runLogParent, $_.Exception.Message)
            }
        }

        Set-VideoScreenshotLogFile -Path $resolvedRunLogFile
    }
    else {
        Clear-VideoScreenshotLogFile
    }

    try {
    # Context contains Version, Config (defaults incl. VideoExtensions), RunGuid, SaveFolder, RequestedFps
    Write-Message -Level Info -Message ("videoscreenshot module v{0} starting (Mode={1}, FPS={2}, SaveFolder=""{3}"")" -f ($context.Version -as [string]), $mode, $FramesPerSecond, $SaveFolder)
    if (-not [string]::IsNullOrWhiteSpace($resolvedRunLogFile)) {
        Write-Message -Level Info -Message ("Run log file: {0}" -f $resolvedRunLogFile)
    }

    # --- Crop-only fast path ---------------------------------------------------
    if ($CropOnly) {
        # Warn about ignored capture-related parameters if supplied
        $captureParams = @('SourceFolder', 'UseVlcSnapshots', 'FramesPerSecond', 'TimeLimitSeconds', 'MaxPerVideoSeconds',
            'GdiFullscreen', 'VlcStartupTimeoutSeconds', 'VerifyVideos', 'VideoProbeTimeoutSeconds', 'IncludeExtensions',
            'ClearSnapshotsBeforeRun', 'VideoLimit', 'ResumeFile', 'ProcessedLogPath')
        $ignored = @()
        foreach ($n in $captureParams) {
            if ($PSBoundParameters.ContainsKey($n)) { $ignored += $n }
        }
        if ($ignored.Count -gt 0) {
            Write-Message -Level Warn -Message ("CropOnly: ignoring capture-related parameter(s): {0}" -f ($ignored -join ', '))
        }

        # Validate inputs for cropper
        if (-not [string]::IsNullOrWhiteSpace($PythonScriptPath)) {
            if (-not (Test-Path -LiteralPath $PythonScriptPath)) {
                throw "PythonScriptPath not found: $PythonScriptPath"
            }
        }
        else {
            Write-Debug "CropOnly: PythonScriptPath not supplied; will attempt module invocation via 'python -m media.crop_colours'."
        }
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
            Write-Message -Level Warn -Message ("Cropper failed: {0}" -f $_.Exception.Message)
            throw
        }

        $null = Write-Message -Level Info -Message ("videoscreenshot module v{0} finished — crop-only mode" -f ($context.Version))
        Write-Debug 'TRACE Start-VideoBatch: leaving (CropOnly)'
        return
    }

    # Optional cropper pre-validation (fail fast with clear diagnostics)
    if ($RunCropper) {
        if (-not [string]::IsNullOrWhiteSpace($PythonScriptPath)) {
            if (-not (Test-Path -LiteralPath $PythonScriptPath)) {
                throw "PythonScriptPath not found: $PythonScriptPath"
            }
            if (-not [string]::IsNullOrWhiteSpace($PythonExe)) {
                try {
                    $null = Get-Command -Name $PythonExe -ErrorAction Stop
                }
                catch {
                    throw "Python executable not found or not on PATH: $PythonExe"
                }
            }
        }
        else {
            # No explicit script path: we'll rely on `python -m media.crop_colours` (PYTHONPATH auto-configured)
            Write-Debug "RunCropper: PythonScriptPath not supplied; will invoke via 'python -m media.crop_colours'."
        }
    }

    if (-not (Test-Path -LiteralPath $SourceFolder)) {
        Write-Message -Level Error -Message "SourceFolder not found: $SourceFolder"
        throw "Invalid SourceFolder."
    }
    $resolvedVlcExe = if (-not [string]::IsNullOrWhiteSpace($VlcExe)) {
        if (Test-Path -LiteralPath $VlcExe -PathType Leaf) {
            $VlcExe
        }
        elseif (Test-Path -LiteralPath $VlcExe -PathType Container) {
            # A directory was given — try appending vlc.exe
            $candidate = Join-Path $VlcExe 'vlc.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate } else {
                Write-Message -Level Error -Message "vlc.exe not found inside directory: $VlcExe"
                throw "VLC missing."
            }
        }
        else {
            Write-Message -Level Error -Message "VlcExe not found: $VlcExe"
            throw "VLC missing."
        }
    }
    elseif (Get-Command vlc -ErrorAction SilentlyContinue) {
        (Get-Command vlc).Source
    }
    else {
        # Check the default VLC install location on Windows
        $defaultVlc = Join-Path $env:ProgramFiles 'VideoLAN\VLC\vlc.exe'
        if (Test-Path -LiteralPath $defaultVlc) { $defaultVlc }
        else {
            Write-Message -Level Error -Message "VLC (vlc.exe) not found in PATH. Use -VlcExe to specify the path."
            throw "VLC missing."
        }
    }
    # Resolve processed log path and read processed/resume set (P0)
    $processedLog = if ([string]::IsNullOrWhiteSpace($ProcessedLogPath)) {
        Join-Path $SaveFolder '.processed_videos.txt'
    }
    else {
        $ProcessedLogPath
    }
    # Always produce a usable HashSet for O(1) membership checks; log diagnostics.
    try {
        $processedSet = Get-ResumeIndex -Path $processedLog
    }
    catch {
        Write-Message -Level Warn -Message ("Resume index read failed ('{0}'): {1}" -f $processedLog, $_.Exception.Message)
        $processedSet = $null
    }
    if ($null -eq $processedSet) {
        $processedSet = [System.Collections.Generic.HashSet[string]]::new()
    }
    if ($processedSet -isnot [System.Collections.Generic.HashSet[string]]) {
        $tmpSet = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($v in @($processedSet)) {
            if (-not [string]::IsNullOrWhiteSpace($v)) { $null = $tmpSet.Add($v) }
        }
        $processedSet = $tmpSet
    }
    if (-not [string]::IsNullOrWhiteSpace($ResumeFile)) {
        try { [void]$processedSet.Add((Resolve-VideoPath -Path $ResumeFile)) } catch {
            # Failed to add resume file to processed set (possibly path resolution issue)
        }
    }
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
        if (Get-Command -Name Test-VideoPlayable -ErrorAction SilentlyContinue) {
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
    $vlcLogFile = Join-Path $SaveFolder ".vlc_log_$runGuid.txt"
    try {
        if (Test-Path -LiteralPath $vlcLogFile -PathType Leaf) {
            Remove-Item -LiteralPath $vlcLogFile -Force -ErrorAction Stop
        }
        New-Item -ItemType File -Path $vlcLogFile -Force -ErrorAction Stop | Out-Null
        $context | Add-Member -NotePropertyName VlcLogPath -NotePropertyValue $vlcLogFile -Force
        Write-Debug "VLC sidecar log: $vlcLogFile"
    }
    catch {
        Write-Message -Level Warn -Message ("Unable to initialize VLC sidecar logfile '{0}': {1}. Continuing without VLC file logging." -f $vlcLogFile, $_.Exception.Message)
        $context | Add-Member -NotePropertyName VlcLogPath -NotePropertyValue $null -Force
        $vlcLogFile = $null
    }

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
        if ($pidFile -and (Test-Path -LiteralPath $pidFile)) {
            Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        }
        if ($vlcLogFile -and (Test-Path -LiteralPath $vlcLogFile)) {
            Remove-Item -LiteralPath $vlcLogFile -Force -ErrorAction SilentlyContinue
        }
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
            else {
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

        # Post-measure (use stats objects so they aren't unused)
        $framesDelta = 0
        $achievedFps = $null
        if ($UseVlcSnapshots) {
            if ($null -ne $snapStats) {
                $framesDelta = [int]$snapStats.FramesDelta
                if ($snapStats.ElapsedSeconds -gt 0 -and $framesDelta -gt 0) {
                    $achievedFps = [Math]::Round($framesDelta / [double]$snapStats.ElapsedSeconds, 3)
                }
            }
            else {
                # Fallback: compute delta from disk counts
                $postCount = (Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
                $framesDelta = [int]($postCount - $preCount)
            }
        }
        else {
            if ($null -ne $gdiStats) {
                $framesDelta = [int]$gdiStats.FramesSaved
                $achievedFps = $gdiStats.AchievedFps
            }
            else {
                # Fallback for GDI mode: compute delta from disk counts
                $postCount = (Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
                $framesDelta = [int]($postCount - $preCount)
            }
        }

        # De-duplicate consecutive identical frames if requested.
        # Gated on $framesDelta > 0 so a zero-capture run (e.g. VLC produced nothing)
        # never de-dups pre-existing frames from a previous run on the same prefix.
        $dedupStats = $null
        if ($DeduplicateFrames -and -not $processingFailed -and $framesDelta -gt 0) {
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

        # Final disk count — always recompute for accuracy; when de-dup ran, use the
        # post-dedup count only when it is positive (new unique frames were added).
        # When the delta is 0 or negative — e.g. VLC overwrote pre-existing files with
        # the same names rather than appending new ones, so the file count did not rise —
        # fall back to the stats-derived $framesDelta so valid captures are not falsely
        # flagged as NoFrames.
        $actualPostCount = (Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $actualFramesDelta = [int]($actualPostCount - $preCount)
        if ($null -ne $dedupStats) {
            if ($actualFramesDelta -gt 0) {
                $framesDelta = $actualFramesDelta
            }
            # else: overwrite case or de-dup removed below preCount — keep stats-derived value
        }
        elseif ($actualFramesDelta -gt $framesDelta) {
            Write-Debug ("Stats reported {0} frames but disk shows {1} frames; using actual count" -f $framesDelta, $actualFramesDelta)
            $framesDelta = $actualFramesDelta
        }

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
    if ($pidFile -and (Test-Path -LiteralPath $pidFile)) {
        try {
            Remove-Item -LiteralPath $pidFile -Force -ErrorAction Stop
            Write-Debug "Cleaned up PID registry: $pidFile"
        }
        catch {
            Write-Message -Level Warn -Message ("Failed to remove PID registry file '{0}': {1}" -f $pidFile, $_.Exception.Message)
        }
    }

    # Clean VLC's sidecar logfile on successful runs; retain it deterministically
    # when processing failed so startup/decoder diagnostics remain available.
    if ($vlcLogFile -and (Test-Path -LiteralPath $vlcLogFile)) {
        if ($retainVlcLog) {
            Write-Message -Level Warn -Message ("Retaining VLC sidecar log after failure: {0}" -f $vlcLogFile)
        }
        else {
            try {
                Remove-Item -LiteralPath $vlcLogFile -Force -ErrorAction Stop
                Write-Debug "Cleaned up VLC sidecar log: $vlcLogFile"
            }
            catch {
                Write-Message -Level Warn -Message ("Failed to remove VLC sidecar log '{0}': {1}" -f $vlcLogFile, $_.Exception.Message)
            }
        }
    }

    $null = Write-Message -Level Info -Message ("videoscreenshot module v{0} finished — processed {1} file(s)" -f ($context.Version), $processedCount)
    Write-Debug 'TRACE Start-VideoBatch: leaving (no output intended)'
    return
    }
    finally {
        Clear-VideoScreenshotLogFile
    }
}
