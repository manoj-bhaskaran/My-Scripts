function Resolve-UniqueDirectoryPath {
    <#
    .SYNOPSIS
        Generates a unique directory path by appending a timestamp suffix if the path already exists.

    .DESCRIPTION
        If the provided directory path does not exist, returns it unchanged.
        If the directory exists (collision), appends a unique suffix derived from the current timestamp
        and an optional counter, ensuring the returned path is always unique.

        This is useful for safely creating directories without overwriting or merging with
        existing content when collision avoidance is preferred.

    .PARAMETER Path
        The desired path for a directory.

    .EXAMPLE
        Resolve-UniqueDirectoryPath -Path "C:\backups\archive_20250411"
        Returns: C:\backups\archive_20250411 (if it doesn't exist)

    .EXAMPLE
        Resolve-UniqueDirectoryPath -Path "C:\backups\archive_20250411"
        Returns: C:\backups\archive_20250411_20250411143025 (if directory exists)

    .OUTPUTS
        [string] A unique directory path, either the original (if no collision) or a variant with a timestamp suffix.

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
        return (Resolve-UniquePathCore -Path $Path -IsDirectory:$true)
    }
}
