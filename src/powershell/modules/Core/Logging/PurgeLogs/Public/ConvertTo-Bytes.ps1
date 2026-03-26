function ConvertTo-Bytes {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Converts a human-readable size string into a long byte value.

    .PARAMETER Size
    A string like "250MB", "250M", "1GB", "1G", "1024KB", "1024K", etc.

    .EXAMPLE
    ConvertTo-Bytes -Size "500MB"

    .EXAMPLE
    ConvertTo-Bytes -Size "10M"
    #>
    param ([string]$Size)
    if ($Size -match '(?i)^([\d\.]+)([KMG](?:B)?)?$') {
        $value = [double]$matches[1]
        $unit = $matches[2].ToUpper()
        switch ($unit) {
            'K' { return [long]($value * 1KB) }
            'KB' { return [long]($value * 1KB) }
            'M' { return [long]($value * 1MB) }
            'MB' { return [long]($value * 1MB) }
            'G' { return [long]($value * 1GB) }
            'GB' { return [long]($value * 1GB) }
            default { return [long]$value }
        }
    }
    else {
        throw "Invalid size format: $Size (e.g., 50M, 50MB, 100K, 100KB)"
    }
}
