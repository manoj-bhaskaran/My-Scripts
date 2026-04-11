function Get-SafeName {
    <#
    .SYNOPSIS
        Sanitizes a file or folder name by removing invalid characters.

    .DESCRIPTION
        Removes or replaces invalid filesystem characters (as defined by .NET's
        GetInvalidFileNameChars), and optionally truncates the result to a maximum length.
        Trims trailing dots and spaces, and provides a fallback name if the result is empty.

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
        $invalid = [System.IO.Path]::GetInvalidFileNameChars()
        $sb = [System.Text.StringBuilder]::new()

        foreach ($ch in $Name.ToCharArray()) {
            if ($invalid -contains $ch -or $ch -eq [char]':') {
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
