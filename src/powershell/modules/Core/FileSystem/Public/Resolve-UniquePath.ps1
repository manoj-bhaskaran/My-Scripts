function Resolve-UniquePath {
    <#
    .SYNOPSIS
        Generates a unique file path by appending a timestamp suffix if the path already exists.

    .DESCRIPTION
        If the provided path does not exist, returns it unchanged.
        If the path exists (collision), appends a unique suffix derived from the current timestamp
        and an optional counter, ensuring the returned path is always unique.

        This is useful for safely writing files without overwriting existing content
        when collision avoidance is preferred.

    .PARAMETER Path
        The desired path for a file.

    .EXAMPLE
        Resolve-UniquePath -Path "C:\logs\report.txt"
        Returns: C:\logs\report.txt (if it doesn't exist)

    .EXAMPLE
        Resolve-UniquePath -Path "C:\logs\report.txt"
        Returns: C:\logs\report_20250411143025.txt (if report.txt exists)

    .OUTPUTS
        [string] A unique file path, either the original (if no collision) or a variant with a timestamp suffix.

    .NOTES
        Uses the Resolve-UniquePathCore helper function internally.
        The suffix format is: _yyyyMMddHHmmss[_counter]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )

    process {
        if (-not (Test-Path -LiteralPath $Path)) {
            return $Path
        }
        return (Resolve-UniquePathCore -Path $Path -IsDirectory:$false)
    }
}
