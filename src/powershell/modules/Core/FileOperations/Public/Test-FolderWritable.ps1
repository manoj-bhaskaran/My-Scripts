function Test-FolderWritable {
    <#
    .SYNOPSIS
        Tests if a folder is writable.

    .DESCRIPTION
        Tests whether a folder exists and is writable by attempting to create
        a temporary file. Optionally creates the folder if it doesn't exist.

    .PARAMETER Path
        Path to the folder to test.

    .PARAMETER SkipCreate
        Don't create the folder if it doesn't exist (default: $false).

    .EXAMPLE
        if (Test-FolderWritable "C:\\temp") {
            Write-Host "Folder is writable"
        }

    .EXAMPLE
        if (Test-FolderWritable "C:\\logs" -SkipCreate) {
            Write-Host "Folder exists and is writable"
        }

    .OUTPUTS
        [bool] True if folder is writable, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$SkipCreate
    )

    if (-not (Test-Path $Path)) {
        if ($SkipCreate) {
            return $false
        }

        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
        catch {
            Write-Warning "Failed to create directory '$Path': $_"
            return $false
        }
    }

    # Test write permissions by creating a temporary file
    $testFile = Join-Path $Path ".write_test_$([guid]::NewGuid().ToString('N'))"

    try {
        [IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Verbose "Folder '$Path' is not writable: $_"
        return $false
    }
}
