<#
.SYNOPSIS
Entry point for batch processing (back-compat wrapper around the old script’s parameters).
.DESCRIPTION
Implements resume & processed logging, advanced timing controls, and full pipeline wiring.
#>
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

    # Pipeline completion parameters
    [switch]$RunCropper,
    [string]$PythonScriptPath,
    [string]$PythonExe,
    [switch]$ClearSnapshotsBeforeRun
  )

  # Enforce pwsh 7+ at runtime (friendly error if invoked directly)
  Assert-Pwsh7OrThrow

  # Policy: helpers throw; only this function emits user-facing messages.
  $mode    = ($UseVlcSnapshots ? 'VLC snapshots' : 'GDI+ desktop')
  $runGuid = [Guid]::NewGuid().ToString('N').Substring(0,8)
  $context = New-VideoRunContext -RequestedFps $FramesPerSecond -SaveFolder $SaveFolder -RunGuid $runGuid

  $mod = $MyInvocation.MyCommand.Module
  $verString = if ($null -ne $mod) { $mod.Version.ToString() } else { 'dev' }
  Write-Message -Level Info -Message ("videoscreenshot module v{0} starting (Mode={1}, FPS={2}, SaveFolder=""{3}"")" -f $verString, $mode, $FramesPerSecond, $SaveFolder)

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

  if ($RunCropper -and [string]::IsNullOrWhiteSpace($PythonScriptPath)) {
    Write-Message -Level Warn -Message "RunCropper was specified but PythonScriptPath is empty. Cropper will be skipped."
  }

  # Initialize PID registry for this run
  $pidFile = Initialize-PidRegistry -Context $context -SaveFolder $SaveFolder -RunGuid $runGuid
  Write-Debug "PID registry: $pidFile"

  # Discover videos
  $videos = Get-ChildItem -Path (Join-Path $SourceFolder '*') -Recurse -File -Include *.mp4,*.mkv,*.avi,*.mov,*.m4v,*.wmv
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

    # Prefer MaxPerVideoSeconds (if provided) over TimeLimitSeconds
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
        $baseWait   = if ($capSeconds -gt 0) { [int]$capSeconds } else { [int]$context.Config.SnapshotFallbackTimeoutSeconds }
        $waitSeconds = [int]([Math]::Max(1, $baseWait + [int]$StartupGraceSeconds))
        $snapStats  = Wait-ForSnapshotFrames -SaveFolder $SaveFolder -ScenePrefix $scenePrefix -MaxSeconds $waitSeconds
      } else {
        $dur      = if ($capSeconds -gt 0) { [int]$capSeconds } else { [int]$context.Config.GdiCaptureDefaultSeconds }
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

  # After capture loop, optionally run the cropper once over the source folder
  if ($RunCropper -and -not [string]::IsNullOrWhiteSpace($PythonScriptPath)) {
    try {
      $crop = Invoke-Cropper -PythonScriptPath $PythonScriptPath `
                             -PythonExe $PythonExe `
                             -InputFolder $SourceFolder `
                             -Debug:($PSBoundParameters.ContainsKey('Debug'))
      Write-Message -Level Info -Message ("Cropper finished OK (elapsed={0}s, exit={1})" -f $crop.ElapsedSeconds, $crop.ExitCode)
    } catch {
      Write-Message -Level Warn -Message ("Cropper failed: {0}" -f $_.Exception.Message)
    }
  }

  Write-Message -Level Info -Message (
    "videoscreenshot module v{0} finished — processed {1} file(s)" -f
    ($MyInvocation.MyCommand.Module.Version.ToString()), $processedCount
  )
}
