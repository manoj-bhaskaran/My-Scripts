function New-DirectoryIfMissing {
    <#
    .SYNOPSIS
        Creates a directory if it doesn't exist.

    .DESCRIPTION
        Ensures a directory exists by creating it if necessary.
        Returns the DirectoryInfo object for the directory.

    .PARAMETER Path
        Directory path to create

    .PARAMETER Force
        Create parent directories if needed

    .EXAMPLE
        New-DirectoryIfMissing -Path "C:\temp\logs"
        Creates the directory if it doesn't exist.

    .EXAMPLE
        New-DirectoryIfMissing -Path "C:\temp\deep\nested\folder" -Force
        Creates the directory and all parent directories if needed.

    .OUTPUTS
        [System.IO.DirectoryInfo] The directory object.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Force
    )

    if (Test-Path $Path) {
        Write-Verbose "Directory already exists: $Path"
        return Get-Item -Path $Path
    }

    try {
        if (-not $Force) {
            # Check if parent directory exists when Force is not used
            $parentPath = Split-Path -Path $Path -Parent
            if ($parentPath -and -not (Test-Path $parentPath)) {
                throw "Cannot create directory '$Path' because parent directory '$parentPath' does not exist. Use -Force to create parent directories."
            }
        }

        $params = @{
            ItemType = 'Directory'
            Path     = $Path
        }

        if ($Force) {
            $params.Force = $true
        }

        $dir = New-Item @params
        Write-Verbose "Created directory: $Path"
        return $dir
    } catch {
        Write-Error "Failed to create directory '$Path': $_"
        throw
    }
}
