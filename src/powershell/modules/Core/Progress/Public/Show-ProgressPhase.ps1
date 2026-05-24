function Show-ProgressPhase {
    <#
    .SYNOPSIS
        Write-Progress wrapper that computes PercentComplete and respects QuietMode.
    .DESCRIPTION
        Centralizes percentage math and quiet-mode suppression for all phase progress bars.
        Callers pass Current/Total item counts; the helper computes PercentComplete and
        delegates rendering to Show-Progress.
    .PARAMETER Activity
        The progress-bar activity label.
    .PARAMETER Status
        The status message shown on the progress bar.
    .PARAMETER Current
        Current item index used to compute PercentComplete.
    .PARAMETER Total
        Total item count (denominator for percentage). Zero is safe — guarded against division by zero.
    .PARAMETER QuietMode
        When $true, all progress output is suppressed and the function returns immediately.
    .PARAMETER CurrentOperation
        Optional sub-operation text shown beneath the status line.
    .PARAMETER Completed
        When set, closes the named progress bar instead of updating it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Activity,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][int]$Current,
        [Parameter(Mandatory)][int]$Total,
        [Parameter(Mandatory)][bool]$QuietMode,
        [string]$CurrentOperation,
        [switch]$Completed
    )

    if ($QuietMode) { return }

    $pct = [math]::Min(100, [int]($Current / [math]::Max(1, $Total) * 100))
    Show-Progress -Activity $Activity -Status $Status -PercentComplete $pct `
        -CurrentOperation $CurrentOperation -Completed:$Completed
}
