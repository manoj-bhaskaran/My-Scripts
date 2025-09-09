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
  .OUTPUTS
  PSCustomObject with FramesDelta and ElapsedSeconds.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix,
    [ValidateRange(1,86400)][int]$MaxSeconds = 300,
    [ValidateRange(50,5000)][int]$PollMs = 200
  )
  $start = Get-Date
  $pattern = "$ScenePrefix*.png"
  $initial = (Get-ChildItem -Path $SaveFolder -Filter $pattern -File -ErrorAction SilentlyContinue | Measure-Object).Count
  $lastCount = $initial

  while ((New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds -lt $MaxSeconds) {
    $count = (Get-ChildItem -Path $SaveFolder -Filter $pattern -File -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($count -gt $lastCount) {
      $lastCount = $count
    }
    Start-Sleep -Milliseconds $PollMs
  }

  $elapsed = [int][Math]::Ceiling((New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds)
  [pscustomobject]@{
    FramesDelta    = [int]($lastCount - $initial)
    ElapsedSeconds = $elapsed
  }
}
