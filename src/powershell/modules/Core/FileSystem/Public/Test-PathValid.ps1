function Test-PathValid {
    <#
    .SYNOPSIS
        Tests if a path is valid according to filesystem rules.

    .DESCRIPTION
        Validates that a path conforms to filesystem naming rules and
        does not contain invalid characters. Does not check if the
        path exists, only if it is syntactically valid.

    .PARAMETER Path
        The path to validate

    .PARAMETER AllowWildcards
        If specified, allows wildcard characters (* and ?) in the path

    .EXAMPLE
        Test-PathValid -Path "C:\temp\file.txt"
        Returns $true if the path is valid.

    .EXAMPLE
        Test-PathValid -Path "C:\temp\<invalid>.txt"
        Returns $false because < and > are invalid characters.

    .EXAMPLE
        Test-PathValid -Path "C:\temp\*.txt" -AllowWildcards
        Returns $true because wildcards are allowed.

    .OUTPUTS
        [bool] True if the path is valid, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path,

        [switch]$AllowWildcards
    )

    # Empty or whitespace-only paths are invalid
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    try {
        # Get invalid path characters
        $invalidPathChars = [System.IO.Path]::GetInvalidPathChars()

        # Check for invalid path characters
        foreach ($char in $invalidPathChars) {
            if ($Path.Contains($char)) {
                Write-Verbose "Path contains invalid character: $char"
                return $false
            }
        }

        # Get invalid filename characters (stricter check)
        $invalidFileNameChars = [System.IO.Path]::GetInvalidFileNameChars()

        # Also check for additional characters that are invalid in filenames
        # These may not be caught by GetInvalidFileNameChars on all platforms
        $additionalInvalidChars = @('<', '>', '|')

        # Extract filename component if possible
        $fileName = Split-Path -Path $Path -Leaf -ErrorAction SilentlyContinue

        if ($fileName) {
            # Check standard invalid filename characters
            foreach ($char in $invalidFileNameChars) {
                # Skip wildcards if allowed
                if ($AllowWildcards -and ($char -eq '*' -or $char -eq '?')) {
                    continue
                }

                if ($fileName.Contains($char)) {
                    Write-Verbose "Filename contains invalid character: $char"
                    return $false
                }
            }

            # Check additional invalid characters
            foreach ($char in $additionalInvalidChars) {
                if ($fileName.Contains($char)) {
                    Write-Verbose "Filename contains invalid character: $char"
                    return $false
                }
            }
        }

        # Try to get the full path to validate it can be resolved
        # This will throw if the path format is invalid
        $null = [System.IO.Path]::GetFullPath($Path)

        return $true
    } catch {
        Write-Verbose "Path validation failed: $_"
        return $false
    }
}
