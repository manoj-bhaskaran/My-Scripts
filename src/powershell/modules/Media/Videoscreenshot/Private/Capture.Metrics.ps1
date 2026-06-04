<#
.SYNOPSIS
  Post-capture frame-delta and FPS measurement helper.
.DESCRIPTION
  Derives FramesDelta and AchievedFps from VLC-snapshot stats, GDI stats, or
  disk-count fallbacks; reconciles those values against the post-dedup disk count;
  and applies the overwrite-case guard. Branches on UseVlcSnapshots, SnapStats,
  GdiStats, and DedupStats. This is pure data-preparation logic with no VLC
  dependency.
#>

<#
.SYNOPSIS
  Compute the captured-frame delta and achieved FPS after a single-video capture.
.DESCRIPTION
  Derives FramesDelta from VLC-snapshot stats (with ElapsedSeconds-based FPS),
  GDI stats (FramesSaved / AchievedFps), or disk-count fallbacks when stats
  are null. Then reconciles with the post-dedup disk count, applying the
  overwrite-case guard documented in Start-VideoBatch.

  Returns [pscustomobject]@{ FramesDelta=[int]; AchievedFps=$null-or-double }.
.PARAMETER SnapStats
  Return value from Wait-ForSnapshotFrames or Invoke-FfmpegSceneChangeCapture;
  may be $null.
.PARAMETER GdiStats
  Return value from Invoke-GdiCapture; may be $null.
.PARAMETER DedupStats
  Return value from Invoke-SnapshotDedup; $null when dedup did not run.
.PARAMETER PreCount
  Frame-file count before capture began (used for disk-count fallback and
  dedup reconciliation).
.PARAMETER ScenePrefix
  Filename prefix (e.g. "myvideo_") used for the *.png glob.
.PARAMETER SaveFolder
  Folder that receives captured PNG frames.
.PARAMETER UseVlcSnapshots
  When set, uses SnapStats; otherwise uses GdiStats.
.OUTPUTS
  [pscustomobject] @{ FramesDelta = [int]; AchievedFps = [nullable double] }
#>
function Measure-CaptureFrameDelta {
    [CmdletBinding()]
    param(
        $SnapStats,
        $GdiStats,
        $DedupStats,
        [Parameter(Mandatory)][int]$PreCount,
        [Parameter(Mandatory)][string]$ScenePrefix,
        [Parameter(Mandatory)][string]$SaveFolder,
        [switch]$UseVlcSnapshots
    )

    $framesDelta = 0
    $achievedFps = $null

    if ($UseVlcSnapshots) {
        if ($null -ne $SnapStats) {
            $framesDelta = [int]$SnapStats.FramesDelta
            if ($SnapStats.ElapsedSeconds -gt 0 -and $framesDelta -gt 0) {
                $achievedFps = [Math]::Round($framesDelta / [double]$SnapStats.ElapsedSeconds, 3)
            }
        }
        else {
            $postCount = (Get-ChildItem -Path $SaveFolder -Filter "${ScenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
            $framesDelta = [int]($postCount - $PreCount)
        }
    }
    else {
        if ($null -ne $GdiStats) {
            $framesDelta = [int]$GdiStats.FramesSaved
            $achievedFps = $GdiStats.AchievedFps
        }
        else {
            $postCount = (Get-ChildItem -Path $SaveFolder -Filter "${ScenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
            $framesDelta = [int]($postCount - $PreCount)
        }
    }

    # Reconcile with the post-dedup / final disk count.
    # When dedup ran and the file count rose above preCount, use the disk count for accuracy.
    # When the delta is zero or negative (VLC overwrote pre-existing files with the same names
    # rather than appending), keep the stats-derived value so valid captures are not
    # falsely flagged as NoFrames.
    $actualPostCount = (Get-ChildItem -Path $SaveFolder -Filter "${ScenePrefix}*.png" -File -ErrorAction SilentlyContinue | Measure-Object).Count
    $actualFramesDelta = [int]($actualPostCount - $PreCount)
    if ($null -ne $DedupStats) {
        if ($actualFramesDelta -gt 0) {
            $framesDelta = $actualFramesDelta
        }
    }
    elseif ($actualFramesDelta -gt $framesDelta) {
        Write-Debug ("Stats reported {0} frames but disk shows {1} frames; using actual count" -f $framesDelta, $actualFramesDelta)
        $framesDelta = $actualFramesDelta
    }

    return [pscustomobject]@{ FramesDelta = [int]$framesDelta; AchievedFps = $achievedFps }
}
