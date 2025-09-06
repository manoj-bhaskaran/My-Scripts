<#
.SYNOPSIS
Entry point for batch processing (back-compat wrapper around the old script’s parameters).
.DESCRIPTION
Thin orchestrator for now; calls into private helpers. More logic will move here in follow-up PRs.
#>
function Start-VideoBatch {
  [CmdletBinding()]
  param(
    [string]$SourceFolder = (Join-Path $PSScriptRoot 'videos'),
    [string]$SaveFolder   = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Screenshots'),
    [ValidateRange(1,60)][int]$FramesPerSecond = 1,
    [int]$TimeLimitSeconds = 0,
    [int]$VideoLimit = 0,
    [switch]$UseVlcSnapshots,
    [switch]$GdiFullscreen,
    [int]$VlcStartupTimeoutSeconds = 10,
    # Pipeline completion parameters
    [switch]$RunCropper,
    [string]$PythonScriptPath,
    [string]$PythonExe,
    [switch]$ClearSnapshotsBeforeRun
  )
  # Policy: helpers throw; only this function emits user-facing messages.
  $mode = ($UseVlcSnapshots ? 'VLC snapshots' : 'GDI+ desktop')
  $runGuid = [Guid]::NewGuid().ToString('N').Substring(0,8)
  $context = New-VideoRunContext -RequestedFps $FramesPerSecond -SaveFolder $SaveFolder -RunGuid $runGuid
  Write-Message -Level Info -Message ("videoscreenshot module v{0} starting (Mode={1}, FPS={2}, SaveFolder=""{3}"")" -f $context.Version, $mode, $FramesPerSecond, $SaveFolder)
 
  if (-not (Test-Path -LiteralPath $SourceFolder)) { Write-Message -Level Error -Message "SourceFolder not found: $SourceFolder"; throw "Invalid SourceFolder." }
  if (-not (Get-Command vlc -ErrorAction SilentlyContinue)) { Write-Message -Level Error -Message "VLC (vlc.exe) not found in PATH."; throw "VLC missing." }
  Test-FolderWritable -Folder $SaveFolder | Out-Null

  if ($RunCropper -and [string]::IsNullOrWhiteSpace($PythonScriptPath)) {
    Write-Message -Level Warn -Message "RunCropper was specified but PythonScriptPath is empty. Cropper will be skipped."
  }

  # Initialize PID registry for this run
  $pidFile = Initialize-PidRegistry -Context $context -SaveFolder $SaveFolder -RunGuid $runGuid
  Write-Debug "PID registry: $pidFile"

  # Discover videos
  $videos = Get-ChildItem -Path (Join-Path $SourceFolder '*') -Recurse -File -Include *.mp4,*.mkv,*.avi,*.mov,*.m4v,*.wmv
  if (-not $videos) { Write-Message -Level Warn -Message "No videos found under $SourceFolder."; return }

  $processedCount = 0

  foreach ($video in $videos) {
    if ($VideoLimit -gt 0 -and $processedCount -ge $VideoLimit) { break }

    $scenePrefix = ('{0}_' -f [IO.Path]::GetFileNameWithoutExtension($video.Name))

    if ($ClearSnapshotsBeforeRun) {
      # Best-effort clean-up of prior runs for this video
      Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    $preCount = (Get-ChildItem -Path $SaveFolder -Filter "${scenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count

    $p = $null
    $snapStats = $null
    $gdiStats  = $null
    $stopAfter = if ($TimeLimitSeconds -gt 0) { [double]$TimeLimitSeconds } else { 0 }

    try {
      $p = Start-Vlc -Context $context -VideoPath $video.FullName -SaveFolder $SaveFolder -UseVlcSnapshots:$UseVlcSnapshots -RequestedFps $FramesPerSecond -StopAtSeconds $stopAfter -GdiFullscreen:$GdiFullscreen -StartupTimeoutSeconds $VlcStartupTimeoutSeconds

      if ($UseVlcSnapshots) {
        $waitSeconds = if ($TimeLimitSeconds -gt 0) { [int]$TimeLimitSeconds } else { [int]$context.Config.SnapshotFallbackTimeoutSeconds }
        $snapStats = Wait-ForSnapshotFrames -SaveFolder $SaveFolder -ScenePrefix $scenePrefix -MaxSeconds $waitSeconds
      }
      else {
        $dur = if ($TimeLimitSeconds -gt 0) { [int]$TimeLimitSeconds } else { [int]$context.Config.GdiCaptureDefaultSeconds }
        $gdiStats = Invoke-GdiCapture -DurationSeconds $dur -Fps $FramesPerSecond -SaveFolder $SaveFolder -ScenePrefix $scenePrefix
      }
    }
    catch {
      Write-Message -Level Error -Message ("Processing failed for: {0} — {1}" -f $video.FullName, $_.Exception.Message)
      throw
    }
    finally {
      if ($p) { Stop-Vlc -Context $context -Process $p; Unregister-RunPid -Context $context -ProcessId $p.Id }
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
      if ($RunCropper -and -not [string]::IsNullOrWhiteSpace($PythonScriptPath)) {
        try {
          Invoke-Cropper -PythonScriptPath $PythonScriptPath -PythonExe $PythonExe -SaveFolder $SaveFolder -ScenePrefix $scenePrefix | Out-Null
          Write-Message -Level Info -Message "Cropper finished OK."
        } catch {
          Write-Message -Level Warn -Message ("Cropper failed for {0}: {1}" -f $video.FullName, $_.Exception.Message)
        }
      }
    }

    $processedCount++
  }

  Write-Message -Level Info -Message ("videoscreenshot module v{0} finished — processed {1} file(s)" -f ($MyInvocation.MyCommand.Module.Version.ToString()), $processedCount)
 }
