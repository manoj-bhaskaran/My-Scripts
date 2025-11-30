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
