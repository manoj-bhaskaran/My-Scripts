function Write-LogDebug {
    <#
    .SYNOPSIS
    Logs a message at DEBUG level.
    .DESCRIPTION
    Writes a log entry with level DEBUG (10).
    Timestamps now include human-readable timezone abbreviations (e.g., IST, UTC) instead of numeric offsets.
    .PARAMETER Message
    The debug message to log.
    .PARAMETER Metadata
    Optional key-value metadata.
    #>
    param($Message, [hashtable]$Metadata = @{})
    Write-Log -Level 'DEBUG' -NumericLevel 10 -Message $Message -Metadata $Metadata
}
