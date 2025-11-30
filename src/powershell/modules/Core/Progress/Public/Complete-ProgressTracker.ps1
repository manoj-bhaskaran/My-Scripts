function Complete-ProgressTracker {
    <#
    .SYNOPSIS
        Marks a progress tracker as completed.

    .DESCRIPTION
        Displays 100% progress and then hides the progress bar.

    .PARAMETER Tracker
        Progress tracker object from New-ProgressTracker.

    .PARAMETER FinalMessage
        Optional final message to display.

    .EXAMPLE
        Complete-ProgressTracker -Tracker $progress

    .EXAMPLE
        Complete-ProgressTracker -Tracker $progress -FinalMessage "Processing complete"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Tracker,

        [Parameter(Mandatory = $false)]
        [string]$FinalMessage = ""
    )

    # Show 100% completion
    $status = if ($FinalMessage) {
        $FinalMessage
    }
    else {
        "Completed ($($Tracker.Current) of $($Tracker.Total))"
    }

    Show-Progress -Activity $Tracker.Activity -PercentComplete 100 -Status $status

    # Hide progress bar
    Start-Sleep -Milliseconds 500
    Show-Progress -Activity $Tracker.Activity -Completed
}
