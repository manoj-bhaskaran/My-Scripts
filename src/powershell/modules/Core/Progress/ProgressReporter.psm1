############################################################
# ProgressReporter.psm1
# Standardized progress reporting utilities
############################################################

<#
.SYNOPSIS
    Provides standardized progress reporting utilities.

.DESCRIPTION
    This module provides reusable functions for displaying progress indicators
    and combining progress with logging.

.NOTES
    Version: 1.0.0
    Date: 2025-11-20
    License: Apache License, Version 2.0
#>

function Show-Progress {
    <#
    .SYNOPSIS
        Displays standardized progress indicator.

    .DESCRIPTION
        Wrapper around Write-Progress with consistent formatting and optional completion handling.

    .PARAMETER Activity
        Description of the activity being performed.

    .PARAMETER PercentComplete
        Percentage complete (0-100).

    .PARAMETER Status
        Current status message (optional).

    .PARAMETER Id
        Progress bar ID for nested progress (default: 0).

    .PARAMETER CurrentOperation
        Current operation being performed (optional).

    .PARAMETER Completed
        Mark progress as completed and hide the progress bar.

    .EXAMPLE
        Show-Progress -Activity "Processing files" -PercentComplete 50 -Status "50 of 100 files"

    .EXAMPLE
        Show-Progress -Activity "Processing files" -Completed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$PercentComplete = 0,

        [Parameter(Mandatory = $false)]
        [string]$Status = "",

        [Parameter(Mandatory = $false)]
        [int]$Id = 0,

        [Parameter(Mandatory = $false)]
        [string]$CurrentOperation = "",

        [Parameter(Mandatory = $false)]
        [switch]$Completed
    )

    if ($Completed) {
        Write-Progress -Activity $Activity -Id $Id -Completed
    }
    else {
        $params = @{
            Activity        = $Activity
            PercentComplete = $PercentComplete
            Id              = $Id
        }

        if ($Status) {
            $params['Status'] = $Status
        }

        if ($CurrentOperation) {
            $params['CurrentOperation'] = $CurrentOperation
        }

        Write-Progress @params
    }
}

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
    } else {
        0
    }

    # Create status message
    $status = "($Current/$Total, ${percent}%)"
    $logMessage = "$Message $status"

    # Log message if logging framework is available
    if (Get-Command Write-LogInfo -ErrorAction SilentlyContinue) {
        Write-LogInfo $logMessage
    } else {
        Write-Verbose $logMessage
    }

    # Show progress bar
    $activityText = if ($Activity) { $Activity } else { $Message }
    Show-Progress -Activity $activityText -PercentComplete $percent -Status $status -Id $Id
}

function New-ProgressTracker {
    <#
    .SYNOPSIS
        Creates a progress tracker object for managing progress state.

    .DESCRIPTION
        Returns a hashtable object for tracking progress across multiple operations.
        Useful for complex scripts with multiple stages.

    .PARAMETER Total
        Total number of items to process.

    .PARAMETER Activity
        Description of the activity.

    .PARAMETER UpdateFrequency
        How often to update progress (every N items, default: 1).

    .EXAMPLE
        $progress = New-ProgressTracker -Total 1000 -Activity "Processing files"
        Update-ProgressTracker -Tracker $progress -Increment 1
        Complete-ProgressTracker -Tracker $progress

    .OUTPUTS
        [hashtable] Progress tracker object.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Total,

        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $false)]
        [int]$UpdateFrequency = 1
    )

    return @{
        Total           = $Total
        Current         = 0
        Activity        = $Activity
        UpdateFrequency = $UpdateFrequency
        LastUpdate      = 0
    }
}

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
        } else {
            0
        }

        $statusText = if ($Status) {
            $Status
        } else {
            "$($Tracker.Current) of $($Tracker.Total)"
        }

        Show-Progress -Activity $Tracker.Activity -PercentComplete $percent -Status $statusText
        $Tracker.LastUpdate = $Tracker.Current
    }
}

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
    } else {
        "Completed ($($Tracker.Current) of $($Tracker.Total))"
    }

    Show-Progress -Activity $Tracker.Activity -PercentComplete 100 -Status $status

    # Hide progress bar
    Start-Sleep -Milliseconds 500
    Show-Progress -Activity $Tracker.Activity -Completed
}

function Write-ProgressStatus {
    <#
    .SYNOPSIS
        Writes a status message without updating the progress bar.

    .DESCRIPTION
        Updates the CurrentOperation field of the progress bar without changing
        the percentage. Useful for showing what specific operation is being performed.

    .PARAMETER Activity
        Activity description.

    .PARAMETER Status
        Current status.

    .PARAMETER Id
        Progress bar ID (default: 0).

    .EXAMPLE
        Write-ProgressStatus -Activity "Processing files" -Status "Copying file.txt"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [int]$Id = 0
    )

    Write-Progress -Activity $Activity -CurrentOperation $Status -Id $Id
}

# Export module members
Export-ModuleMember -Function @(
    'Show-Progress',
    'Write-ProgressLog',
    'New-ProgressTracker',
    'Update-ProgressTracker',
    'Complete-ProgressTracker',
    'Write-ProgressStatus'
)
