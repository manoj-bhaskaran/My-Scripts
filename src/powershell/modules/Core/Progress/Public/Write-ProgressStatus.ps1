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
