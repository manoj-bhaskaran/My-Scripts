function Wait-ForSnapshotFrames {
    <#
  .SYNOPSIS
  Polls the snapshot folder for frames with a given prefix and returns frame delta + elapsed seconds.
  .PARAMETER SaveFolder
  Destination folder where VLC writes scene snapshots.
  .PARAMETER ScenePrefix
  File prefix used by VLC's scene filter (e.g., "<video>_").
  .PARAMETER MaxSeconds
  Maximum seconds to wait before returning (defaults to 300 if not supplied by caller).
  .PARAMETER PollMs
  Polling interval in milliseconds (default 200).
  .PARAMETER Process
  Optional VLC process to monitor. When provided, polling stops early after process exits + grace period.
  .PARAMETER GracePeriodSeconds
  Seconds to continue polling after VLC exits to capture buffered frames (default 2).
  .PARAMETER IdleTimeoutSeconds
  Seconds without a new frame before breaking early (idle-frame stall detection). Only active after
  WarmUpSeconds have elapsed and while the process is still alive. Set to 0 to disable (default).
  .PARAMETER WarmUpSeconds
  Seconds at the start of the session during which idle detection is suppressed, to allow
  slow-starting sources to produce their first frame (default 10).
  .OUTPUTS
  PSCustomObject with FramesDelta and ElapsedSeconds.
  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix,
        [ValidateRange(1, 86400)][int]$MaxSeconds = 300,
        [ValidateRange(50, 5000)][int]$PollMs = 200,
        [System.Diagnostics.Process]$Process,
        [ValidateRange(0, 60)][int]$GracePeriodSeconds = 2,
        [ValidateRange(0, 3600)][int]$IdleTimeoutSeconds = 0,
        [ValidateRange(0, 3600)][int]$WarmUpSeconds = 10
    )
    $start = Get-Date
    $pattern = "$ScenePrefix*.png"
    $initial = (Get-ChildItem -Path $SaveFolder -Filter $pattern -File -ErrorAction SilentlyContinue | Measure-Object).Count
    $lastCount = $initial
    $vlcExitTime = $null
    $lastFrameTime = $start

    while ((New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds -lt $MaxSeconds) {
        $now = Get-Date
        $count = (Get-ChildItem -Path $SaveFolder -Filter $pattern -File -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($count -gt $lastCount) {
            $lastCount = $count
            $lastFrameTime = $now
        }

        # Check if VLC has exited (early termination to prevent duplicate screenshots)
        if ($Process) {
            try {
                $Process.Refresh()
                if ($Process.HasExited) {
                    if ($null -eq $vlcExitTime) {
                        $vlcExitTime = $now
                        Write-Debug "VLC exited; continuing for grace period of $GracePeriodSeconds seconds"
                    }
                    # Exit polling after grace period to avoid duplicate frames
                    if ((New-TimeSpan -Start $vlcExitTime -End (Get-Date)).TotalSeconds -ge $GracePeriodSeconds) {
                        Write-Debug "Grace period elapsed; stopping snapshot polling"
                        break
                    }
                }
                elseif ($IdleTimeoutSeconds -gt 0) {
                    # Idle-frame stall detection: only fire after warm-up window has elapsed
                    $elapsed = (New-TimeSpan -Start $start -End $now).TotalSeconds
                    if ($elapsed -ge $WarmUpSeconds) {
                        $idleSeconds = (New-TimeSpan -Start $lastFrameTime -End $now).TotalSeconds
                        if ($idleSeconds -ge $IdleTimeoutSeconds) {
                            Write-Message -Level Warn -Message ("Idle-frame stall detected: no new frames for {0:F0}s; abandoning VLC session early." -f $idleSeconds)
                            break
                        }
                    }
                }
            }
            catch {
                # Process object may be disposed; treat as exited
                if ($null -eq $vlcExitTime) {
                    $vlcExitTime = $now
                }
            }
        }

        Start-Sleep -Milliseconds $PollMs
    }

    $elapsed = [int][Math]::Ceiling((New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds)
    [pscustomobject]@{
        FramesDelta    = [int]($lastCount - $initial)
        ElapsedSeconds = $elapsed
    }
}
