<#
.OVERVIEW
  VLC argument builders and process helpers.

EXPECTED Context.Config SHAPE (used for configurability; all optional):
  @{
    PollIntervalMs = 200
    StopVlcWaitMs  = 5000
    WaitProcessTimeoutSeconds = 3
    Vlc = @{
      BaseArgs  = @('--no-qt-privacy-ask','--no-video-title-show','--no-loop','--no-repeat','--rate','1','--play-and-exit')
      ExtraArgs = @()
      Scene = @{
        Format   = 'png'             # default snapshot format
        BaseArgs = @('--intf','dummy','--video-filter=scene')
      }
      Gdi = @{
        Args = @('--qt-minimal-view') # appended when using GDI playback
      }
    }
  }
#>
<# 
  NOTE (Configurability): Defaults in this file can be overridden via the run context:
  $Context.Config.Vlc.* (e.g., BaseArgs, Scene.Format). Defaults < Context.Config overrides < function parameters.
#>
<#
.SYNOPSIS
  Build common VLC arguments shared across modes.
.DESCRIPTION
  Produces a base set of arguments for VLC that suppress UI noise and ensure
  deterministic playback. Honors an optional stop time when provided.
.PARAMETER StopAtSeconds
  Optional stop-time in seconds. Rounded to nearest whole second when > 0.
.OUTPUTS
  string[] of arguments suitable for process invocation.
#>
function Get-VlcArgsCommon {
  param([double]$StopAtSeconds = 0)
  # Defaults may be overridden by Context.Config.Vlc.BaseArgs at the call site.
  $vlcargs = @(
    '--no-qt-privacy-ask',
    '--no-video-title-show',
    '--no-loop',
    '--no-repeat',
    '--rate','1',
    '--play-and-exit'
  )
  if ($StopAtSeconds -gt 0) {
    $rounded = [int][Math]::Round($StopAtSeconds)
    $vlcargs += @('--stop-time',"$rounded"); Write-Debug "VLC --stop-time=$rounded"
  }
  ,$vlcargs
}
<#
.SYNOPSIS
  Build VLC UI flags relevant when using desktop/GDI capture.
.PARAMETER GdiFullscreen
  When set, requests fullscreen/top-most/minimal view.
.OUTPUTS
  string[] UI-related arguments (may be empty).
#>
function Get-VlcArgsGdi {
  param(
    [switch]$GdiFullscreen,
    [string[]]$GdiArgs,
    [psobject]$Context
  )
  $uiArgs = @()
  if ($GdiFullscreen) {
    $uiArgs += @('--fullscreen','--video-on-top','--qt-minimal-view')
  }
  # Allow config-driven defaults and caller-provided extras (order matters)
  if ($Context -and $Context.Config -and $Context.Config.Vlc -and $Context.Config.Vlc.Gdi -and $Context.Config.Vlc.Gdi.Args) {
    $uiArgs += [string[]]$Context.Config.Vlc.Gdi.Args
  }
  if ($GdiArgs) { $uiArgs += $GdiArgs }
  ,$uiArgs
}
<#
.SYNOPSIS
  Build VLC scene-snapshot (frame dumping) arguments.
.DESCRIPTION
  Computes an effective scene ratio using the source FPS (queried via Get-VideoFps
  when available) and the requested output FPS. Falls back to a configurable default
  source FPS when detection is unavailable.
.PARAMETER VideoPath
  Absolute path to the video file.
.PARAMETER SaveFolder
  Folder where PNG/JPG frames will be written.
.PARAMETER RequestedFps
  Target frames per second to approximate via --scene-ratio.
.PARAMETER SceneFormat
  Image format for snapshots (e.g., 'png' or 'jpg'). Defaults to 'png' if not supplied.
.PARAMETER SceneArgs
  Additional scene filter arguments to append (e.g., advanced tunables).
.PARAMETER Context
  Optional run context to source default Format/BaseArgs from Config.
.OUTPUTS
  string[] of arguments enabling the 'scene' video filter.
#>
function Get-VlcArgsSnapshot {
  param(
    [psobject]$Context,
    [Parameter(Mandatory)][string]$VideoPath,
    [Parameter(Mandatory)][string]$SaveFolder,
    [Parameter(Mandatory)][int]$RequestedFps,
    # Robustness: constrain to known formats to avoid invalid VLC invocations
    [ValidateSet('png','jpg','jpeg')]
    [string]$SceneFormat = 'png',
    [string[]]$SceneArgs
  )
  # Default to 30 fps if Get-VideoFps is not available; emit a warning so callers see it.
  $base = 30.0
  try {
    if (Get-Command Get-VideoFps -ErrorAction SilentlyContinue) {
      $fps = Get-VideoFps -Path $VideoPath
      if ($fps -gt 0) { $base = [double]$fps }
      else { Write-Warning "Get-VideoFps returned non-positive FPS for '$VideoPath'. Using default $base." }
    } else {
      Write-Warning "Get-VideoFps not found; using default source FPS $base for '$VideoPath'."
    }
  } catch {
    Write-Warning ("Get-VideoFps failed for '{0}': {1}. Using default {2}." -f $VideoPath, $_.Exception.Message, $base)
  }
  $ratio = [int][Math]::Max(1,[Math]::Round($base / [double]$RequestedFps))
  Write-Debug "Snapshots: video_fps=$base; requested=$RequestedFps; --scene-ratio=$ratio; format=$SceneFormat"
  # Prefer Context-provided base scene args/format when available
  $baseSceneArgs = @('--intf','dummy','--video-filter=scene')
  if ($Context -and $Context.Config -and $Context.Config.Vlc -and $Context.Config.Vlc.Scene) {
    if ($null -ne $Context.Config.Vlc.Scene.Format -and -not $PSBoundParameters.ContainsKey('SceneFormat')) {
      $SceneFormat = [string]$Context.Config.Vlc.Scene.Format
    }
    if ($Context.Config.Vlc.Scene.BaseArgs) {
      $baseSceneArgs = [string[]]$Context.Config.Vlc.Scene.BaseArgs
    }
  }
  $sceneArgsList = @()
  $sceneArgsList += $baseSceneArgs
  $sceneArgsList += @('--scene-path', $SaveFolder
             '--scene-prefix', ("{0}_" -f [IO.Path]::GetFileNameWithoutExtension($VideoPath)),
             '--scene-format', $SceneFormat,
             '--scene-ratio',"$ratio")
  if ($SceneArgs) { $sceneArgsList += $SceneArgs }
  ,$sceneArgsList
}

<#
.SYNOPSIS
  Validate required configuration keys on the run context.
.DESCRIPTION
  Ensures Context.Config and core timing knobs exist and are sane before using them.
  This improves maintainability by catching typos/missing keys early with a clear error.
.PARAMETER Context
  Run context object expected to include a Config property.
#>
function Test-VideoConfig {
  [CmdletBinding()]
  param([Parameter(Mandatory)][psobject]$Context)
  if ($null -eq $Context -or $null -eq $Context.Config) {
    throw "Context.Config is missing."
  }
  $cfg = $Context.Config
  foreach ($k in @('PollIntervalMs','StopVlcWaitMs','WaitProcessTimeoutSeconds')) {
    if ($null -eq $cfg.$k -or ($cfg.$k -as [int]) -lt 0) {
      throw "Context.Config.$k is missing or invalid (expected non-negative integer)."
    }
  }
}

<#
.SYNOPSIS
  Start a VLC process with the provided arguments and basic startup validation.
.DESCRIPTION
  Launches VLC headlessly with stdout/stderr redirected. Collects early output
  for diagnostics and respects a startup timeout watchdog.
.PARAMETER Context
  Run context object; expected to contain Config timing knobs.
.PARAMETER Arguments
  Complete argument vector to pass to VLC.
.PARAMETER StartupTimeoutSeconds
  Maximum seconds to wait before declaring startup failure.
.OUTPUTS
  [Diagnostics.Process] of the started VLC instance.
#>
function Start-VlcProcess {
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [Parameter(Mandatory)][string[]]$Arguments,
    [Parameter(Mandatory)][int]$StartupTimeoutSeconds
  )
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
  # Maintainability: thread-safe buffering avoids interleaved lines in parallel runs.
  $p.add_OutputDataReceived({ param($s,$e) if ($e.Data){ [Threading.Monitor]::Enter($outLock); try{ [void]$stdoutSb.AppendLine($e.Data) } finally { [Threading.Monitor]::Exit($outLock) }; Write-Debug $e.Data } })
  $p.add_ErrorDataReceived( { param($s,$e) if ($e.Data){ [Threading.Monitor]::Enter($errLock);  try{ [void]$stderrSb.AppendLine($e.Data) } finally { [Threading.Monitor]::Exit($errLock)  }; Write-Debug $e.Data } })

  $start = Get-Date
  # Documentation: we quote/escape here to avoid argument splitting by the host shell.
  Write-Debug ("Starting VLC with args: {0}" -f $psi.Arguments)
  $null = $p.Start()
  $p.BeginOutputReadLine()
  $p.BeginErrorReadLine()
  $deadline = $start.AddSeconds([int]$StartupTimeoutSeconds)
  # Simplicity-over-complexity: polling watchdog keeps import-time logic straightforward.
  while ((Get-Date) -lt $deadline) {
    if ($p.HasExited) { break }
    Start-Sleep -Milliseconds $Context.Config.PollIntervalMs
  }
  if ($p.HasExited -and $p.ExitCode -ne 0) {
    $stderrText = $stderrSb.ToString()
    throw ("VLC startup failed (ExitCode={0}). stderr: {1}" -f $p.ExitCode, $stderrText)
  }
  return $p
}
<#
.SYNOPSIS
  Compose arguments and start VLC for the requested capture mode.
.DESCRIPTION
  Validates inputs, consults Context.Config for defaults/overrides (e.g., VLC
  base args, default scene format), and optionally appends user-supplied extras.
  Precedence (Configurability): built-in defaults < Context.Config.Vlc.* < function parameters.
  Throws if required Context.Config timing knobs are missing (see Test-VideoConfig).
.PARAMETER Context
  Run context object (must include Config with timing knobs; may include Vlc defaults).
.PARAMETER VideoPath
  Path to the input video file (validated to exist).
.PARAMETER SaveFolder
  Folder to write out frames (validated to exist).
.PARAMETER UseVlcSnapshots
  Use scene snapshot mode instead of desktop/GDI playback.
.PARAMETER RequestedFps
  Target output FPS (used to compute --scene-ratio when snapshots are used).
.PARAMETER StopAtSeconds
  Optional per-video stop time (0 means run to completion/monitor decides).
.PARAMETER GdiFullscreen
  When using GDI playback, request fullscreen/top-most/minimal view.
.PARAMETER StartupTimeoutSeconds
  Timeout for VLC process to initialize.
.PARAMETER SceneFormat
  Snapshot image format; defaults to Context.Config.Vlc.Scene.Format or 'png'.
.PARAMETER ExtraArgs
  Additional VLC flags appended to the final argument vector.
.OUTPUTS
  [Diagnostics.Process] for the started VLC.
#>
function Start-Vlc {
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$VideoPath,
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Container })][string]$SaveFolder,
    [switch]$UseVlcSnapshots,
    [Parameter(Mandatory)][int]$RequestedFps,
    [double]$StopAtSeconds,
    [switch]$GdiFullscreen,
    [int]$StartupTimeoutSeconds = 10,
    [string]$SceneFormat,
    [string[]]$SceneArgs,
    [string[]]$GdiArgs,
    [string[]]$ExtraArgs
  )
  # Maintainability: early validation of context config to catch missing keys/typos.
  Test-VideoConfig -Context $Context
  # Resolve defaults/overrides from Context.Config.Vlc
  $cfgVlc = $Context.Config.Vlc
  $baseArgs = if ($cfgVlc -and $cfgVlc.BaseArgs) { [string[]]$cfgVlc.BaseArgs } else { Get-VlcArgsCommon -StopAtSeconds $StopAtSeconds }
  $fmt = if ($SceneFormat) { $SceneFormat } elseif ($cfgVlc -and $cfgVlc.Scene -and $cfgVlc.Scene.Format) { [string]$cfgVlc.Scene.Format } else { 'png' }

  $vlcargs = @()
  # Argument assembly order (documented for maintainability):
  # 1) Target media path
  # 2) Mode-specific args (snapshot/GDI)
  # 3) Common/base args (defaults or Context.Config.Vlc.BaseArgs)
  # 4) Caller-provided extras (last-wins)
  $vlcargs += @($VideoPath)
  if ($UseVlcSnapshots) {
    $vlcargs += Get-VlcArgsSnapshot -Context $Context -VideoPath $VideoPath -SaveFolder $SaveFolder -RequestedFps $RequestedFps -SceneFormat $fmt -SceneArgs $SceneArgs
  } else {
    $vlcargs += Get-VlcArgsGdi -GdiFullscreen:$GdiFullscreen -GdiArgs $GdiArgs -Context $Context
  }
  # Append common/base args (may contain stop-time if caller used Get-VlcArgsCommon)
  $vlcargs += $baseArgs
  # Append any caller-provided extras last (Robustness: ignore null/empty elements).
  if ($ExtraArgs -and $ExtraArgs.Count -gt 0) {
    $extraClean = @()
    foreach ($ea in $ExtraArgs) {
      if ($ea -is [string] -and -not [string]::IsNullOrWhiteSpace($ea)) {
        $extraClean += $ea
      } else {
        Write-Warning "Ignoring invalid ExtraArgs element (null/empty or non-string)."
      }
    }
    if ($extraClean.Count -gt 0) { $vlcargs += $extraClean }
  }

  $p = Start-VlcProcess -Context $Context -Arguments $vlcargs -StartupTimeoutSeconds $StartupTimeoutSeconds
  Register-RunPid -Context $Context -ProcessId $p.Id
  return $p
}
<#
.SYNOPSIS
  Attempt graceful VLC shutdown, then force-kill if needed.
.PARAMETER Context
  Run context object with timing knobs (StopVlcWaitMs/WaitProcessTimeoutSeconds).
.PARAMETER Process
  The VLC process object to stop.
#>
function Stop-Vlc {
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [Parameter(Mandatory)][Diagnostics.Process]$Process
  )
  try { $null = $Process.CloseMainWindow() } catch {}
  try { $null = $Process.WaitForExit($Context.Config.StopVlcWaitMs) } catch {}
  if (-not $Process.HasExited) {
    Write-Debug "VLC still running; forcing PID $($Process.Id)"
    try { Stop-Process -Id $Process.Id -Force; $null = Wait-Process -Id $Process.Id -Timeout $Context.Config.WaitProcessTimeoutSeconds -ErrorAction SilentlyContinue; $null = $Process.Refresh() } catch {}
  }
}
