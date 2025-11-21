function Test-VideoPlayable {
    <#
  .SYNOPSIS
  Lightweight validation that VLC can open a video.
  .DESCRIPTION
  Launches VLC in a headless/dummy interface for ~1 second and checks the exit code
  as a quick “can this open & start?” probe. This is intentionally fast to keep
  batch throughput high and to avoid long delays on broken files.

  Exit policy:
    - Returns $true on exit code 0 (success).
    - Returns $false on a clean non-zero exit. In this case, stderr/stdout are captured
      and emitted at Debug level to aid troubleshooting.
    - Throws only on immediate startup failures (e.g., process launch errors).

  Notes:
    - The 1s window is a trade-off; longer probes reduce false negatives on slow sources
      (e.g., cold network shares) but slow the batch. If you need a longer probe, adjust
      the stop-time flag here or add a parameterized variant.
  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    # Process setup
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'vlc'  # Resolves via PATH; we intentionally don’t pre-check here.
    # ArgumentList handles quoting for us; we run a minimal, non-interactive session:
    #   --intf dummy       : no UI
    #   --play-and-exit    : exit once playback ends/hits stop-time
    #   --start-time 0     : seek to start (defensive)
    #   --stop-time  1     : ~1s probe (see trade-off note in DESCRIPTION)
    foreach ($a in @('--intf', 'dummy', '--play-and-exit', '--start-time', '0', '--stop-time', '1', $Path)) {
        $psi.ArgumentList.Add($a)
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true

    # Launch VLC
    $p = [Diagnostics.Process]::new()
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw "Failed to start VLC for validation." }
    $p.WaitForExit()

    if ($p.ExitCode -eq 0) { return $true }

    # Non-zero exit: capture stderr/stdout for diagnostics (Debug level to avoid noise).
    # We read after the process exits to avoid async complexity.
    try {
        $stderr = $p.StandardError.ReadToEnd()
    }
    catch { $stderr = '' }
    try {
        $stdout = $p.StandardOutput.ReadToEnd()
    }
    catch { $stdout = '' }

    if ($stderr) { Write-Debug ("Test-VideoPlayable: VLC stderr => {0}" -f $stderr.Trim()) }
    if ($stdout) { Write-Debug ("Test-VideoPlayable: VLC stdout => {0}" -f $stdout.Trim()) }
    Write-Debug ("Test-VideoPlayable: VLC exited with code {0} for '{1}'" -f $p.ExitCode, $Path)

    # Treat non-zero as not playable; caller decides to skip
    return $false
}