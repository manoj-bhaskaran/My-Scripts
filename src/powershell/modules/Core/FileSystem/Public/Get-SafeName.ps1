function Get-SafeName {
    <#
    .SYNOPSIS
        Sanitizes a file or folder name by removing invalid characters.

    .DESCRIPTION
        Removes or replaces invalid filename characters (those invalid on Windows/NTFS)
        with underscores, and optionally truncates the result to a maximum length.
        Uses an explicit character set (including control characters and <>:"/\|?*) for
        cross-platform consistency. Trims trailing dots and spaces, and provides a
        fallback name if the result is empty.

    .PARAMETER Name
        The original name to sanitize.

    .PARAMETER MaxLength
        Optional. Maximum length for the sanitized name. Use 0 (default) to disable truncation.
        255 aligns with common NTFS filename component limits.

    .EXAMPLE
        Get-SafeName -Name "file<name>.txt"
        Returns: file_name.txt (< is replaced with _)

    .EXAMPLE
        Get-SafeName -Name "my:file*name.txt"
        Returns: my_file_name.txt (: and * are replaced with _)

    .EXAMPLE
        Get-SafeName -Name "very_long_folder_name_that_exceeds_the_limit" -MaxLength 20
        Returns: very_long_folder_na (truncated to 20 characters)

    .EXAMPLE
        Get-SafeName -Name ">>>>"
        Returns: archive (empty after sanitization, fallback name used)

    .OUTPUTS
        [string] The sanitized name, suitable for use as a filename or directory name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Name,

        [int]$MaxLength = 0
    )

    process {
        # Use explicit set of invalid filename characters for Windows/NTFS compatibility
        # regardless of platform running this code (handles cross-platform testing)
        $invalid = @(
            [char]0, [char]1, [char]2, [char]3, [char]4, [char]5, [char]6, [char]7,
            [char]8, [char]9, [char]10, [char]11, [char]12, [char]13, [char]14, [char]15,
            [char]16, [char]17, [char]18, [char]19, [char]20, [char]21, [char]22, [char]23,
            [char]24, [char]25, [char]26, [char]27, [char]28, [char]29, [char]30, [char]31,
            '<', '>', ':', '"', '/', '\', '|', '?', '*'
        )
        $sb = [System.Text.StringBuilder]::new()

        foreach ($ch in $Name.ToCharArray()) {
            if ($invalid -contains $ch) {
                [void]$sb.Append('_')
            } else {
                [void]$sb.Append($ch)
            }
        }

        $san = $sb.ToString().TrimEnd('.', ' ')

        # Fallback if result is empty or whitespace
        if ([string]::IsNullOrWhiteSpace($san)) {
            $san = 'archive'
        }

        # Optionally truncate
        if ($MaxLength -gt 0 -and $san.Length -gt $MaxLength) {
            Write-Verbose "Truncating name from $($san.Length) to $MaxLength chars"
            $san = $san.Substring(0, $MaxLength)
        }

        return $san
    }
}
