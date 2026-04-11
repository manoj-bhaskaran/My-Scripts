function Format-Bytes {
    <#
    .SYNOPSIS
        Formats a byte count into a human-readable string.

    .DESCRIPTION
        Converts a byte count (Int64) into a human-friendly format with appropriate
        units (B, KB, MB, GB, TB). Useful for displaying file sizes and data volumes.

    .PARAMETER Bytes
        The number of bytes to format.

    .EXAMPLE
        Format-Bytes -Bytes 512
        Returns: 512 B

    .EXAMPLE
        Format-Bytes -Bytes 1048576
        Returns: 1.00 MB

    .EXAMPLE
        Format-Bytes -Bytes 1073741824
        Returns: 1.00 GB

    .EXAMPLE
        Format-Bytes -Bytes 5368709120
        Returns: 5.00 GB

    .OUTPUTS
        [string] A formatted string with units (e.g., "2.50 MB", "1.03 GB").
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [int64]$Bytes
    )

    process {
        if ($Bytes -lt 1KB) { return "$Bytes B" }
        if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
        if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
        if ($Bytes -lt 1TB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
        return "{0:N2} TB" -f ($Bytes / 1TB)
    }
}
