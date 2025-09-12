<#
+.SYNOPSIS
+Entry point for batch video frame capture and optional cropping.
+
+.DESCRIPTION
+Runs VLC-based snapshot capture (or GDI capture) over videos discovered under -SourceFolder,
+writes frames to -SaveFolder, optionally resumes using processed/resume lists, and can run
+the Python cropper over the produced frames. This is the primary public entrypoint; helpers
+throw on failure and this function owns user-facing messages.
+
+.PARAMETER SourceFolder
+Folder to search for input videos (recursive).
+.PARAMETER SaveFolder
+Destination for frame files.
+.PARAMETER FramesPerSecond
+Target FPS for capture (1–60).
+.PARAMETER TimeLimitSeconds
+Legacy per-video time budget (seconds). Prefer -MaxPerVideoSeconds.
+.PARAMETER VideoLimit
+Process at most this many videos (0 = no limit).
+.PARAMETER ProcessedLogPath
+TSV log used for resume/skip; auto-located in SaveFolder when not provided.
+.PARAMETER ResumeFile
+Optional file path/name to resume after.
+.PARAMETER MaxPerVideoSeconds
+Hard cap per video (seconds). Overrides TimeLimitSeconds when > 0.
+.PARAMETER StartupGraceSeconds
+Extra seconds added to snapshot wait to absorb VLC startup.
+.PARAMETER UseVlcSnapshots
+Use VLC scene snapshots; otherwise use GDI capture.
+.PARAMETER GdiFullscreen
+With GDI capture, request fullscreen/top-most playback.
+.PARAMETER VlcStartupTimeoutSeconds
+Timeout for VLC process to initialize.
+.PARAMETER RunCropper
+Run the Python cropper after capture completes.
+.PARAMETER PythonScriptPath
+Path to crop_colours.py (required when -RunCropper).
+.PARAMETER PythonExe
+Python interpreter to use (optional; falls back to py/python in helper).
+.PARAMETER ClearSnapshotsBeforeRun
+Delete existing frames with the scene prefix before each video.
+
+.EXAMPLE
+Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots -RunCropper -PythonScriptPath .\src\python\crop_colours.py
+#>
function Start-VideoBatch {
  [CmdletBinding()]
  param(
    [string]$SourceFolder = (Join-Path $PSScriptRoot 'videos'),
    [string]$SaveFolder   = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Screenshots'),
    [ValidateRange(1,60)][int]$FramesPerSecond = 1,
    [int]$TimeLimitSeconds = 0,
    [int]$VideoLimit = 0,

    # Resume & processed logging
    [string]$ProcessedLogPath,
    [string]$ResumeFile,

    # Advanced timing controls
    [ValidateRange(0,86400)][int]$MaxPerVideoSeconds = 0,
    [ValidateRange(0,60)][int]$StartupGraceSeconds = 2,

    [switch]$UseVlcSnapshots,
    [switch]$GdiFullscreen,
    [int]$VlcStartupTimeoutSeconds = 10,
    # Optional validation / discovery flexibility
    [switch]$VerifyVideos,
    [string[]]$IncludeExtensions,

    # Pipeline completion parameters
    [switch]$RunCropper,
    [string]$PythonScriptPath,
    [string]$PythonExe,
    [switch]$NoAutoInstall,
    [switch]$ClearSnapshotsBeforeRun
  )

  # Enforce pwsh 7+ at runtime (friendly error if invoked directly)
  Assert-Pwsh7OrThrow

  # Policy: helpers throw; only this function emits user-facing messages.
  $mode    = ($UseVlcSnapshots ? 'VLC snapshots' : 'GDI+ desktop')
  $runGuid = [Guid]::NewGuid().ToString('N').Substring(0,8)
  $context = New-VideoRunContext -RequestedFps $FramesPerSecond -SaveFolder $SaveFolder -RunGuid $runGuid

  # Context contains Version, Config (defaults incl. VideoExtensions), RunGuid, SaveFolder, RequestedFps
  Write-Message -Level Info -Message ("videoscreenshot module v{0} starting (Mode={1}, FPS={2}, SaveFolder=""{3}"")" -f ($context.Version -as [string]), $mode, $FramesPerSecond, $SaveFolder)

  # Optional cropper pre-validation (fail fast with clear diagnostics)
  if ($RunCropper) {
    if ([string]::IsNullOrWhiteSpace($PythonScriptPath)) {
      Write-Message -Level Warn -Message "RunCropper was specified but PythonScriptPath is empty. Cropper will be skipped."
    } else {
      if (-not (Test-Path -LiteralPath $PythonScriptPath)) {
        throw "PythonScriptPath not found: $PythonScriptPath"
      }
      if (-not [string]::IsNullOrWhiteSpace($PythonExe)) {
        try {
          $null = Get-Command -Name $PythonExe -ErrorAction Stop
        } catch {
          throw "Python executable not found or not on PATH: $PythonExe"
        }
      }
    }
  }

  if (-not (Test-Path -LiteralPath $SourceFolder)) {
    Write-Message -Level Error -Message "SourceFolder not found: $SourceFolder"
    throw "Invalid SourceFolder."
  }
  if (-not (Get-Command vlc -ErrorAction SilentlyContinue)) {
    Write-Message -Level Error -Message "VLC (vlc.exe) not found in PATH."
    throw "VLC missing."
  }
  Test-FolderWritable -Folder $SaveFolder | Out-Null

  # Resolve processed log path and read processed/resume set (P0)
  $processedLog = if ([string]::IsNullOrWhiteSpace($ProcessedLogPath)) {
    Join-Path $SaveFolder '.processed_videos.txt'
  } else {
    $ProcessedLogPath
  }
  $processedSet = Get-ResumeIndex -Path $processedLog
  if (-not [string]::IsNullOrWhiteSpace($ResumeFile)) {
    try { [void]$processedSet.Add((Resolve-VideoPath -Path $ResumeFile)) } catch {}
  }
  if ($processedSet.Count -gt 0) {
    Write-Message -Level Info -Message (
      "Resume enabled: {0} item(s) will be skipped based on processed/resume lists." -f $processedSet.Count
    )
  }

  # If requested, verify videos only when a verifier is available
  $canVerify = $false
  if ($VerifyVideos) {
    if (Get-Command -Name Test-VideoPlayable -ErrorAction SilentlyContinue) {
      $canVerify = $true
    } else {
      Write-Message -Level Warn -Message "VerifyVideos requested but Test-VideoPlayable is not available; skipping verification."
      $canVerify = $false
    }
  }

  # Initialize PID registry for this run
  $pidFile = Initialize-PidRegistry -Context $context -SaveFolder $SaveFolder -RunGuid $runGuid
  Write-Debug "PID registry: $pidFile"

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
    return
  }

  $processedCount = 0
  $attemptedCount = 0

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
        if (-not (Test-VideoPlayable -Path $video.FullName)) {
          Write-Message -Level Warn -Message ("Skipping not-playable video: {0}" -f $video.FullName)
          if (Get-Command -Name Write-ProcessedLog -ErrorAction SilentlyContinue) {
            Write-ProcessedLog -Path $processedLog -VideoPath $video.FullName -Status 'Skipped' -Reason 'NotPlayable'
          }
          continue
        }
      } catch {
        Write-Message -Level Warn -Message ("Video verification error for {0}: {1}" -f $video.FullName, $_.Exception.Message)
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
    $gdiStats  = $null

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
                     -StartupTimeoutSeconds $VlcStartupTimeoutSeconds

      if ($UseVlcSnapshots) {
        $baseWait = if ($capSeconds -gt 0) { [int]$capSeconds } else { [int]$context.Config.SnapshotFallbackTimeoutSeconds }
        $waitSeconds = [int]([Math]::Max(1, $baseWait + [int]$StartupGraceSeconds))
        $snapStats  = Wait-ForSnapshotFrames -SaveFolder $SaveFolder -ScenePrefix $scenePrefix -MaxSeconds $waitSeconds
      } else {
        $dur = if ($capSeconds -gt 0) { [int]$capSeconds } else { [int]$context.Config.GdiCaptureDefaultSeconds }
        $gdiStats = Invoke-GdiCapture -DurationSeconds $dur -Fps $FramesPerSecond -SaveFolder $SaveFolder -ScenePrefix $scenePrefix
      }
    }
    catch {
      Write-Message -Level Error -Message ("Processing failed for: {0} — {1}" -f $video.FullName, $_.Exception.Message)
      throw
    }
    finally {
      if ($p) {
        Stop-Vlc -Context $context -Process $p
        Unregister-RunPid -Context $context -ProcessId $p.Id
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
      } else {
        # Fallback: compute delta from disk counts
        $postCount   = (Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $framesDelta = [int]($postCount - $preCount)
      }
    } else {
      if ($null -ne $gdiStats) {
        $framesDelta = [int]$gdiStats.FramesSaved
        $achievedFps = $gdiStats.AchievedFps
      }
    }

    if ($framesDelta -le 0) {
      Write-Message -Level Warn -Message ("No frames produced for: {0}" -f $video.FullName)
    } else {
      if ($null -ne $achievedFps) {
        Write-Message -Level Info -Message ("Frames saved: {0} (prefix {1}); achieved FPS: {2}" -f $framesDelta, $scenePrefix, $achievedFps)
      } else {
        Write-Message -Level Info -Message ("Frames saved: {0} (prefix {1})" -f $framesDelta, $scenePrefix)
      }

      # Append processed on success
      Write-ProcessedLog -Path $processedLog -VideoPath $video.FullName -Status 'Processed'
      $processedCount++
    }
  }
  # After capture, optionally run the cropper once over the output images (SaveFolder)
  if ($RunCropper -and -not [string]::IsNullOrWhiteSpace($PythonScriptPath)) {
    try {
      $isDebug = $PSBoundParameters.ContainsKey('Debug')
      $crop = Invoke-Cropper -PythonScriptPath $PythonScriptPath -PythonExe $PythonExe -InputFolder $SaveFolder -NoAutoInstall:$NoAutoInstall -Debug:$isDebug
      Write-Message -Level Info -Message ("Cropper finished OK (exit={0}). STDERR: {1}" -f $crop.ExitCode, ([string]::IsNullOrWhiteSpace($crop.StdErr) ? '<none>' : $crop.StdErr))
    } catch {
      # Include as much context as we have
      Write-Message -Level Warn -Message ("Cropper failed: {0}" -f $_.Exception.Message)
    }
  }

  Write-Message -Level Info -Message ("videoscreenshot module v{0} finished — processed {1} file(s)" -f ($MyInvocation.MyCommand.Module.Version.ToString()), $processedCount)
}
