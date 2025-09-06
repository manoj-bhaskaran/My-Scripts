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
    [int]$VlcStartupTimeoutSeconds = 10
  )
  # Policy: helpers throw; only this function emits user-facing messages.
  $mode = ($UseVlcSnapshots ? 'VLC snapshots' : 'GDI+ desktop')
  Write-Message -Level Info -Message ("videoscreenshot module v{0} starting (Mode={1}, FPS={2}, SaveFolder=""{3}"")" -f $script:VideoScreenshotVersion, $mode, $FramesPerSecond, $SaveFolder)

  if (-not (Test-Path -LiteralPath $SourceFolder)) { Write-Message -Level Error -Message "SourceFolder not found: $SourceFolder"; throw "Invalid SourceFolder." }
  if (-not (Get-Command vlc -ErrorAction SilentlyContinue)) { Write-Message -Level Error -Message "VLC (vlc.exe) not found in PATH."; throw "VLC missing." }
  Test-FolderWritable -Folder $SaveFolder | Out-Null

  # Initialize PID registry for this run
  $runGuid = [Guid]::NewGuid().ToString('N').Substring(0,8)
  $pidFile = Initialize-PidRegistry -SaveFolder $SaveFolder -RunGuid $runGuid
  Write-Debug "PID registry: $pidFile"

  # For PR-1: prove plumbing by starting VLC on the first video and stopping it
  $video = Get-ChildItem -Path (Join-Path $SourceFolder '*') -Recurse -File -Include *.mp4,*.mkv,*.avi,*.mov,*.m4v,*.wmv | Select-Object -First 1
  if (-not $video) { Write-Message -Level Warn -Message "No videos found under $SourceFolder."; return }

  $script:RequestedFps = $FramesPerSecond
  $p = $null
  try {
    $p = Start-Vlc -VideoPath $video.FullName -SaveFolder $SaveFolder -UseVlcSnapshots:$UseVlcSnapshots -StopAtSeconds 0 -GdiFullscreen:$GdiFullscreen -StartupTimeoutSeconds $VlcStartupTimeoutSeconds
    Start-Sleep -Seconds 2   # demonstrate lifecycle
  } finally {
    if ($p) { Stop-Vlc -Process $p; Unregister-RunPid -ProcessId $p.Id }
  }

  Write-Message -Level Info -Message ("videoscreenshot module v{0} finished — OK" -f $script:VideoScreenshotVersion)
}
