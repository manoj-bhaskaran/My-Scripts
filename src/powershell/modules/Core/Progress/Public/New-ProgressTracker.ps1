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
