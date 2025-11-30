function ConvertTo-Bytes {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Converts a human-readable size string into a long byte value.

    .PARAMETER Size
    A string like "250MB", "1GB", "1024KB", etc.

    .EXAMPLE
    ConvertTo-Bytes -Size "500MB"
    #>
    param ([string]$Size)
    if ($Size -match '^([\d\.]+)([KMG]B)?$') {
        $value = [double]$matches[1]
        $unit = $matches[2].ToUpper()
        switch ($unit) {
            'KB' { return [long]($value * 1KB) }
            'MB' { return [long]($value * 1MB) }
            'GB' { return [long]($value * 1GB) }
            default { return [long]$value }
        }
    }
    else {
        throw "Invalid size format: $Size (e.g., 50MB, 100KB)"
    }
}
