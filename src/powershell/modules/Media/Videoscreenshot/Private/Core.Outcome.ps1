function Resolve-Outcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][bool]$HadFrames,
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][bool]$TimedOutPerVideo,
        [Parameter(Mandatory)][bool]$HadErrors
    )
    if ($TimedOutPerVideo) { return [pscustomobject]@{ Processed = $true; Reason = 'TimedOutProcessed' } }
    if (-not $HadErrors -and $ExitCode -eq 0 -and $HadFrames) { return [pscustomobject]@{ Processed = $true; Reason = 'Processed' } }
    $reason = if (-not $HadFrames) { 'NoFrames' }
    elseif ($ExitCode -ne 0) { 'VlcFailed' }
    elseif ($HadErrors) { 'ErrorDuringCapture' }
    else { 'UnknownFailure' }
    [pscustomobject]@{ Processed = $false; Reason = $reason }
}
