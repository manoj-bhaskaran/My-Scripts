function Test-VideoPlayable {
    <#
  .SYNOPSIS
  Lightweight validation that VLC can open a video.
  .DESCRIPTION
  Launches VLC in a headless/dummy interface for ~1 second with VLC writing its
  diagnostics to a sidecar logfile rather than stdout/stderr pipes. Avoiding pipe
  redirection eliminates the OS pipe-buffer deadlock that occurs when VLC's startup
  chatter fills the pipe buffer before WaitForExit returns — the root cause of
  chatty-but-playable videos being falsely reported as NotPlayable.

  Exit policy:
    - Returns $true on exit code 0 (success).
    - Returns $false on a clean non-zero exit. The probe sidecar logfile is read and
      emitted at Debug level to aid troubleshooting.
    - Returns $false on probe timeout after force-killing the VLC process.
    - Throws only on immediate startup failures (e.g., process launch errors).

  Notes:
    - The 1s window is a trade-off; longer probes reduce false negatives on slow sources
      (e.g., cold network shares) but slow the batch. Use TimeoutSeconds to bound
      how long the process may run before it is treated as not playable.
    - Stdout/stderr are NOT redirected; VLC logs to a temp sidecar file to avoid
      pipe-buffer deadlocks (mirrors the capture path fix from #1201).
  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [string]$VlcExe,
        [ValidateRange(1, 300)][int]$TimeoutSeconds = 10,
        [ValidateRange(0, 2)][int]$LogVerbosity = 1
    )
    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    # Create a unique sidecar logfile in temp (distinct from SaveFolder frame globs and capture log).
    # Best-effort: if creation fails, continue without --file-logging rather than throw.
    $probeLogPath = $null
    try {
        $probeLogPath = Join-Path ([System.IO.Path]::GetTempPath()) (".vlcprobe_{0}.log" -f [System.Guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType File -Path $probeLogPath -Force -ErrorAction Stop
    }
    catch {
        Write-Debug ("Test-VideoPlayable: unable to create probe logfile '{0}': {1}; continuing without VLC file logging." -f $probeLogPath, $_.Exception.Message)
        $probeLogPath = $null
    }

    # Build VLC file-logging args (mirrors Get-VlcFileLoggingArgs; no context object available here).
    $loggingArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($probeLogPath)) {
        $loggingArgs = @('--file-logging', '--logfile', $probeLogPath, '--verbose', "$LogVerbosity")
        if ($LogVerbosity -eq 0) { $loggingArgs += '--quiet' }
    }

    # Process setup — stdout/stderr NOT redirected; VLC logs to sidecar to avoid pipe-buffer deadlock.
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = if (-not [string]::IsNullOrWhiteSpace($VlcExe)) { $VlcExe } else { 'vlc' }
    # ArgumentList handles quoting for us; we run a minimal, non-interactive session:
    #   --intf dummy       : no UI
    #   --play-and-exit    : exit once playback ends/hits stop-time
    #   --start-time 0     : seek to start (defensive)
    #   --stop-time  1     : ~1s probe (see trade-off note in DESCRIPTION)
    #   --file-logging ... : direct VLC diagnostics to sidecar; avoids OS pipe-buffer deadlock
    foreach ($a in (@('--intf', 'dummy', '--play-and-exit', '--start-time', '0', '--stop-time', '1') + $loggingArgs + @($Path))) {
        $psi.ArgumentList.Add($a)
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $false
    $psi.RedirectStandardOutput = $false
    $psi.CreateNoWindow = $true

    # Launch VLC
    $p = [Diagnostics.Process]::new()
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw "Failed to start VLC for validation." }

    try {
        $timeoutMs = [Math]::Max(1, $TimeoutSeconds) * 1000
        if (-not $p.WaitForExit($timeoutMs)) {
            Write-Debug ("Test-VideoPlayable: VLC probe timed out after {0}s for '{1}'" -f $TimeoutSeconds, $Path)
            try {
                $p.Kill($true)
            }
            catch {
                try { $p.Kill() } catch { }
            }
            try { $p.WaitForExit(1000) | Out-Null } catch { }
            return $false
        }

        if ($p.ExitCode -eq 0) { return $true }

        # Non-zero exit: read sidecar logfile for diagnostics (Debug level to avoid noise).
        if (-not [string]::IsNullOrWhiteSpace($probeLogPath) -and (Test-Path -LiteralPath $probeLogPath -PathType Leaf)) {
            try {
                $logText = Get-Content -LiteralPath $probeLogPath -Raw -ErrorAction SilentlyContinue
                if ($logText) { Write-Debug ("Test-VideoPlayable: VLC probe log => {0}" -f $logText.Trim()) }
            }
            catch { }
        }
        Write-Debug ("Test-VideoPlayable: VLC exited with code {0} for '{1}'" -f $p.ExitCode, $Path)
    }
    finally {
        $p.Dispose()
        # Deterministic cleanup: always remove the probe logfile (diagnostics already emitted above).
        if (-not [string]::IsNullOrWhiteSpace($probeLogPath) -and (Test-Path -LiteralPath $probeLogPath -PathType Leaf)) {
            try { Remove-Item -LiteralPath $probeLogPath -Force -ErrorAction SilentlyContinue } catch { }
        }
    }

    # Treat non-zero as not playable; caller decides to skip
    return $false
}
