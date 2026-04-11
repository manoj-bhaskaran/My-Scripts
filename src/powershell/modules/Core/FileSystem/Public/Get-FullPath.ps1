function Get-FullPath {
    <#
    .SYNOPSIS
        Normalizes a path to an absolute Windows path.

    .DESCRIPTION
        Converts a path (with forward or backward slashes) to a normalized
        absolute Windows path using standard .NET path resolution.
        Handles both relative and absolute paths.

    .PARAMETER Path
        The path to normalize. May contain forward slashes, relative segments, or be already absolute.

    .EXAMPLE
        Get-FullPath -Path "C:\Users\Admin\Documents"
        Returns: C:\Users\Admin\Documents

    .EXAMPLE
        Get-FullPath -Path "C:/Users/Admin/Documents"
        Returns: C:\Users\Admin\Documents (forward slashes normalized)

    .EXAMPLE
        Get-FullPath -Path "..\parent\folder"
        Returns: C:\parent\folder (relative path resolved)

    .OUTPUTS
        [string] The normalized absolute path with Windows backslashes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )

    process {
        try {
            $normalized = $Path -replace '/', '\'
            return [System.IO.Path]::GetFullPath($normalized)
        } catch {
            Write-Warning "Failed to normalize path '$Path': $_"
            return ($Path -replace '/', '\')
        }
    }
}
