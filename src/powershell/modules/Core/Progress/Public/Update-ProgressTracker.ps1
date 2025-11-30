function Update-ProgressTracker {
    <#
    .SYNOPSIS
        Updates a progress tracker and displays progress if needed.

    .DESCRIPTION
        Increments the progress tracker and displays progress based on UpdateFrequency.

    .PARAMETER Tracker
        Progress tracker object from New-ProgressTracker.

    .PARAMETER Increment
        Amount to increment (default: 1).

    .PARAMETER Force
        Force update even if UpdateFrequency threshold not met.

    .PARAMETER Status
        Optional status message.

    .EXAMPLE
        Update-ProgressTracker -Tracker $progress -Increment 1

    .EXAMPLE
        Update-ProgressTracker -Tracker $progress -Status "Processing file.txt" -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Tracker,

        [Parameter(Mandatory = $false)]
        [int]$Increment = 1,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [string]$Status = ""
    )

    $Tracker.Current += $Increment

    # Check if we should update progress display
    $shouldUpdate = $Force -or (($Tracker.Current - $Tracker.LastUpdate) -ge $Tracker.UpdateFrequency)

    if ($shouldUpdate) {
        $percent = if ($Tracker.Total -gt 0) {
            [int](($Tracker.Current / $Tracker.Total) * 100)
        }
        else {
            0
        }

        $statusText = if ($Status) {
            $Status
        }
        else {
            "$($Tracker.Current) of $($Tracker.Total)"
        }

        Show-Progress -Activity $Tracker.Activity -PercentComplete $percent -Status $statusText
        $Tracker.LastUpdate = $Tracker.Current
    }
}
