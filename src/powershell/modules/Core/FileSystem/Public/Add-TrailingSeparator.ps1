function Add-TrailingSeparator {
    <#
    .SYNOPSIS
        Appends a trailing path separator to a path string if one is not already present.

    .DESCRIPTION
        Uses [IO.Path]::DirectorySeparatorChar so the function works correctly on both
        Windows (backslash) and Linux/macOS (forward slash). The operation is idempotent:
        if the path already ends with either the platform separator or the alternate
        separator, the original string is returned unchanged.

    .PARAMETER Path
        The path string to normalise.

    .EXAMPLE
        Add-TrailingSeparator -Path 'C:\Users\Admin'
        Returns 'C:\Users\Admin\' on Windows.

    .EXAMPLE
        'C:\Temp\' | Add-TrailingSeparator
        Returns 'C:\Temp\' unchanged (already has trailing separator).

    .OUTPUTS
        [string] The path with a guaranteed trailing directory separator.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )
    process {
        $sep    = [IO.Path]::DirectorySeparatorChar
        $altSep = [IO.Path]::AltDirectorySeparatorChar
        if ($Path.EndsWith($sep) -or $Path.EndsWith($altSep)) {
            return $Path
        }
        return $Path + $sep
    }
}
