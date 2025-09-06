function Get-VlcArgsCommon { param([double]$StopAtSeconds = 0)
  $vlcargs = @('--no-qt-privacy-ask','--no-video-title-show','--no-loop','--no-repeat','--rate','1','--play-and-exit')
  if ($StopAtSeconds -gt 0) {
    $rounded = [int][Math]::Round($StopAtSeconds)
    $vlcargs += @('--stop-time',"$rounded"); Write-Debug "VLC --stop-time=$rounded"
  }
  return ,$vlcargs
}
function Get-VlcArgsGdi { param([switch]$GdiFullscreen) if ($GdiFullscreen) { ,@('--fullscreen','--video-on-top','--qt-minimal-view') } else { @() } }
function Get-VlcArgsSnapshot {
  param([Parameter(Mandatory)][string]$VideoPath,[Parameter(Mandatory)][string]$SaveFolder,[Parameter(Mandatory)][int]$RequestedFps)
  # For PR-1 default to 30 fps if Get-VideoFps isn't present in module yet.
  $base = 30.0
  try { if (Get-Command Get-VideoFps -ErrorAction SilentlyContinue) { $fps = Get-VideoFps -Path $VideoPath; if ($fps -gt 0){ $base = [double]$fps } } } catch {}
  $ratio = [int][Math]::Max(1,[Math]::Round($base / [double]$RequestedFps))
  Write-Debug "Snapshots: video_fps=$base; requested=$RequestedFps; --scene-ratio=$ratio"
  ,@('--intf','dummy',
     '--video-filter=scene',
     '--scene-path', $SaveFolder,
     '--scene-prefix', ("{0}_" -f [IO.Path]::GetFileNameWithoutExtension($VideoPath)),
     '--scene-format','png',
     '--scene-ratio',"$ratio")
}
function Start-VlcProcess {
  param([Parameter(Mandatory)][string[]]$Arguments,[Parameter(Mandatory)][int]$StartupTimeoutSeconds)
  $psi = [Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = 'vlc.exe'   # more explicit on Windows; still resolves via PATH
  # Prefer .Arguments string for WinPS 5.1 compatibility (ArgumentList may be unavailable)
  $quotedArgs = $Arguments | ForEach-Object { '"{0}"' -f ($_.Replace('"','""')) }
  $psi.Arguments = [string]::Join(' ', $quotedArgs)
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.CreateNoWindow = $true

  $p = [Diagnostics.Process]::new()
  $p.StartInfo = $psi
  $p.EnableRaisingEvents = $true

  $stdoutSb = New-Object Text.StringBuilder
  $stderrSb = New-Object Text.StringBuilder
  $outLock = New-Object object
  $errLock = New-Object object
  $p.add_OutputDataReceived({ param($s,$e) if ($e.Data){ [Threading.Monitor]::Enter($outLock); try{ [void]$stdoutSb.AppendLine($e.Data) } finally { [Threading.Monitor]::Exit($outLock) }; Write-Debug $e.Data } })
  $p.add_ErrorDataReceived( { param($s,$e) if ($e.Data){ [Threading.Monitor]::Enter($errLock);  try{ [void]$stderrSb.AppendLine($e.Data) } finally { [Threading.Monitor]::Exit($errLock)  }; Write-Debug $e.Data } })

  $start = Get-Date
  $null = $p.Start()
  $p.BeginOutputReadLine()
  $p.BeginErrorReadLine()
  $deadline = $start.AddSeconds([int]$StartupTimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if ($p.HasExited) { break }
    Start-Sleep -Milliseconds $script:Config.PollIntervalMs
  }
  if ($p.HasExited -and $p.ExitCode -ne 0) {
    $stderrText = $stderrSb.ToString()
    throw ("VLC startup failed (ExitCode={0}). stderr: {1}" -f $p.ExitCode, $stderrText)
  }
  return $p
}
function Start-Vlc {
  param(
    [Parameter(Mandatory)][string]$VideoPath,
    [Parameter(Mandatory)][string]$SaveFolder,
    [switch]$UseVlcSnapshots,
    [double]$StopAtSeconds,
    [switch]$GdiFullscreen,
    [int]$StartupTimeoutSeconds = 10
  )
  $vlcargs = @($VideoPath)
  if ($UseVlcSnapshots){ $vlcargs += Get-VlcArgsSnapshot -VideoPath $VideoPath -SaveFolder $SaveFolder -RequestedFps $script:RequestedFps }
  else { $vlcargs += Get-VlcArgsGdi -GdiFullscreen:$GdiFullscreen }
  $vlcargs += Get-VlcArgsCommon -StopAtSeconds $StopAtSeconds
  $p = Start-VlcProcess -Arguments $vlcargs -StartupTimeoutSeconds $StartupTimeoutSeconds
  Register-RunPid -ProcessId $p.Id
  return $p
}
function Stop-Vlc { param([Parameter(Mandatory)][Diagnostics.Process]$Process)
  try { $null = $Process.CloseMainWindow() } catch {}
  try { $null = $Process.WaitForExit($script:Config.StopVlcWaitMs) } catch {}
  if (-not $Process.HasExited) {
    Write-Debug "VLC still running; forcing PID $($Process.Id)"
    try { Stop-Process -Id $Process.Id -Force; $null = Wait-Process -Id $Process.Id -Timeout $script:Config.WaitProcessTimeoutSeconds -ErrorAction SilentlyContinue; $null = $Process.Refresh() } catch {}
  }
}
