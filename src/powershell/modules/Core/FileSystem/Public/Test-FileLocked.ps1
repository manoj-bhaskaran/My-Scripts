function Test-FileLocked {
    <#
    .SYNOPSIS
        Tests if a file is locked by another process.

    .DESCRIPTION
        Attempts to open a file with exclusive access to determine
        if it is currently locked by another process.

    .PARAMETER Path
        File path to test

    .EXAMPLE
        Test-FileLocked -Path "C:\temp\file.txt"
        Returns $true if the file is locked, $false otherwise.

    .OUTPUTS
        [bool] True if the file is locked, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    try {
        # Resolve the path to handle TestDrive: and other PowerShell drives
        $resolvedPath = (Get-Item -Path $Path -ErrorAction Stop).FullName

        $file = [System.IO.File]::Open(
            $resolvedPath,
            'Open',
            'ReadWrite',
            'None'
        )
        $file.Close()
        return $false  # Not locked
    } catch [System.IO.IOException] {
        return $true  # Locked
    } catch {
        Write-Warning "Unexpected error checking file lock: $_"
        return $false
    }
}
