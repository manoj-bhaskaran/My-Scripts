function Test-FileAccessible {
    <#
    .SYNOPSIS
        Tests if a file can be accessed for reading/writing.

    .DESCRIPTION
        Attempts to open a file for the specified access type to verify
        if it is accessible. Returns $true if accessible, $false otherwise.

    .PARAMETER Path
        File path to test

    .PARAMETER Access
        Type of access to test (Read, Write, ReadWrite)

    .EXAMPLE
        Test-FileAccessible -Path "C:\temp\file.txt"
        Tests if the file can be read.

    .EXAMPLE
        Test-FileAccessible -Path "C:\temp\file.txt" -Access Write
        Tests if the file can be written to.

    .OUTPUTS
        [bool] True if the file is accessible, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('Read', 'Write', 'ReadWrite')]
        [string]$Access = 'Read'
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    try {
        $file = Get-Item -Path $Path -ErrorAction Stop

        switch ($Access) {
            'Read' {
                $stream = [System.IO.File]::OpenRead($Path)
                $stream.Close()
                return $true
            }
            'Write' {
                $stream = [System.IO.File]::OpenWrite($Path)
                $stream.Close()
                return $true
            }
            'ReadWrite' {
                return (Test-FileAccessible -Path $Path -Access Read) -and
                (Test-FileAccessible -Path $Path -Access Write)
            }
        }
    }
    catch [System.IO.IOException] {
        Write-Verbose "File not accessible: $_"
        return $false
    }
    catch {
        Write-Verbose "Error checking file access: $_"
        return $false
    }
}
