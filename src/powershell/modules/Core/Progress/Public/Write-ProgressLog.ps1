function Write-ProgressLog {
    <#
    .SYNOPSIS
        Logs progress to both console and log file.

    .DESCRIPTION
        Combines progress reporting with logging. Displays a progress bar and
        writes a log entry with progress information.

    .PARAMETER Message
        Progress message to log.

    .PARAMETER Current
        Current item number.

    .PARAMETER Total
        Total number of items.

    .PARAMETER Activity
        Activity description (optional, uses Message if not provided).

    .PARAMETER Id
        Progress bar ID for nested progress (default: 0).

    .EXAMPLE
        Write-ProgressLog -Message "Processing files" -Current 50 -Total 100

    .EXAMPLE
        for ($i = 1; $i -le 100; $i++) {
            Write-ProgressLog -Message "Processing file" -Current $i -Total 100
            # Do work...
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [int]$Current,

        [Parameter(Mandatory = $true)]
        [int]$Total,

        [Parameter(Mandatory = $false)]
        [string]$Activity = "",

        [Parameter(Mandatory = $false)]
        [int]$Id = 0
    )

    # Calculate percentage
    $percent = if ($Total -gt 0) {
        [int](($Current / $Total) * 100)
    }
    else {
        0
    }

    # Create status message
    $status = "($Current/$Total, ${percent}%)"
    $logMessage = "$Message $status"

    # Log message if logging framework is available
    if (Get-Command Write-LogInfo -ErrorAction SilentlyContinue) {
        Write-LogInfo $logMessage
    }
    else {
        Write-Verbose $logMessage
    }

    # Show progress bar
    $activityText = if ($Activity) { $Activity } else { $Message }
    Show-Progress -Activity $activityText -PercentComplete $percent -Status $status -Id $Id
}
