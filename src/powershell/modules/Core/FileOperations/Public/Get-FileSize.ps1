function Get-FileSize {
    <#
    .SYNOPSIS
        Gets the size of a file in bytes.

    .DESCRIPTION
        Returns the size of a file in bytes. Returns 0 if file doesn't exist.

    .PARAMETER Path
        Path to the file.

    .EXAMPLE
        $size = Get-FileSize "C:\\temp\\file.txt"

    .OUTPUTS
        [long] File size in bytes.
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return 0
    }

    try {
        $file = Get-Item -Path $Path -ErrorAction Stop
        return $file.Length
    }
    catch {
        Write-Warning "Failed to get size of '$Path': $_"
        return 0
    }
}
