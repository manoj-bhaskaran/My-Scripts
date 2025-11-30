function New-DirectoryIfNotExists {
    <#
    .SYNOPSIS
        Creates a directory if it doesn't exist.

    .DESCRIPTION
        Ensures a directory exists by creating it if necessary.
        Returns $true if directory was created, $false if it already existed.

    .PARAMETER Path
        Path to the directory.

    .EXAMPLE
        New-DirectoryIfNotExists "C:\\temp\\logs"

    .OUTPUTS
        [bool] True if directory was created, False if already existed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path $Path) {
        return $false
    }

    try {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        return $true
    }
    catch {
        throw "Failed to create directory '$Path': $_"
    }
}
