<#
.SYNOPSIS
  FFmpeg-backed scene-change snapshot extraction helpers.
.DESCRIPTION
  Provides the opt-in scene-change frame-selection path used by Start-VideoBatch.
  The helper keeps the same output prefix convention as VLC scene snapshots so
  downstream counting, resume, de-duplication, and cropper steps can remain
  unchanged.
#>

function Get-FfmpegCommand {
    try {
        $cmd = Get-Command -Name ffmpeg -ErrorAction Stop
        return $cmd.Source
    }
    catch {
        Write-Debug 'Get-FfmpegCommand: ffmpeg not found on PATH.'
        return $null
    }
}

function Get-FfmpegSceneChangeArgs {
    param(
        [Parameter(Mandatory)][string]$VideoPath,
        [Parameter(Mandatory)][string]$OutputPattern,
        [ValidateRange(0, 1)][double]$Threshold = 0.35,
        [double]$StopAtSeconds = 0,
        [bool]$IncludeFirstFrame = $true,
        [string[]]$BaseArgs = @('-hide_banner', '-nostdin', '-y')
    )

    $thresholdText = $Threshold.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
    $selector = if ($IncludeFirstFrame) {
        "select='eq(n,0)+gt(scene,$thresholdText)'"
    }
    else {
        "select='gt(scene,$thresholdText)'"
    }

    $args = @()
    if ($BaseArgs) { $args += $BaseArgs }
    $args += @('-i', $VideoPath)
    if ($StopAtSeconds -gt 0) {
        $durationText = $StopAtSeconds.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
        $args += @('-t', $durationText)
    }
    $args += @('-vf', $selector, '-vsync', 'vfr', $OutputPattern)
    return $args
}

function Invoke-FfmpegSceneChangeCapture {
    param(
        [Parameter(Mandatory)][string]$FfmpegExe,
        [Parameter(Mandatory)][string]$VideoPath,
        [Parameter(Mandatory)][string]$SaveFolder,
        [Parameter(Mandatory)][string]$ScenePrefix,
        [ValidateRange(0, 1)][double]$Threshold = 0.35,
        [double]$StopAtSeconds = 0,
        [int]$TimeoutSeconds = 0,
        [bool]$IncludeFirstFrame = $true,
        [string[]]$BaseArgs = @('-hide_banner', '-nostdin', '-y')
    )

    if (-not (Test-Path -LiteralPath $VideoPath -PathType Leaf)) {
        throw "VideoPath not found: $VideoPath"
    }
    if (-not (Test-Path -LiteralPath $SaveFolder -PathType Container)) {
        throw "SaveFolder not found: $SaveFolder"
    }

    $preCount = (Get-ChildItem -Path $SaveFolder -Filter "${ScenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
    $outputPattern = Join-Path $SaveFolder ("{0}%05d.png" -f $ScenePrefix)
    $args = Get-FfmpegSceneChangeArgs -VideoPath $VideoPath -OutputPattern $outputPattern -Threshold $Threshold -StopAtSeconds $StopAtSeconds -IncludeFirstFrame $IncludeFirstFrame -BaseArgs $BaseArgs

    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FfmpegExe
    foreach ($arg in $args) { $null = $psi.ArgumentList.Add($arg) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $startedAt = Get-Date
    Write-Debug ("Starting ffmpeg scene-change capture: {0} {1}" -f $FfmpegExe, ([string]::Join(' ', $args)))
    $null = $process.Start()

    $timedOut = $false
    if ($TimeoutSeconds -gt 0) {
        if (-not $process.WaitForExit([int]($TimeoutSeconds * 1000))) {
            $timedOut = $true
            try { $process.Kill($true) } catch { }
            try { $process.WaitForExit(1000) | Out-Null } catch { }
        }
    }
    else {
        $process.WaitForExit()
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $elapsedSeconds = [Math]::Max(0.001, ((Get-Date) - $startedAt).TotalSeconds)

    if ($timedOut) {
        throw ("ffmpeg scene-change capture timed out after {0} second(s). STDERR: {1}" -f $TimeoutSeconds, $stderr)
    }
    if ($process.ExitCode -ne 0) {
        throw ("ffmpeg scene-change capture failed (ExitCode={0}). STDERR: {1}" -f $process.ExitCode, $stderr)
    }

    $postCount = (Get-ChildItem -Path $SaveFolder -Filter "${ScenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
    [pscustomobject]@{
        FramesDelta        = [int]($postCount - $preCount)
        ElapsedSeconds     = [double]$elapsedSeconds
        HitMaxSeconds      = $false
        ProcessAliveAtExit = $false
        Backend            = 'ffmpeg'
        Arguments          = [string[]]$args
        StdOut             = $stdout
        StdErr             = $stderr
    }
}
