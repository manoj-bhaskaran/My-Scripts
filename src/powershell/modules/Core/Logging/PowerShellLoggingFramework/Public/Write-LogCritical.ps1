function Write-LogCritical {
    <#
    .SYNOPSIS
    Logs a message at CRITICAL level.
    .DESCRIPTION
    Writes a log entry with level CRITICAL (50).
    .PARAMETER Message
    The critical error message to log.
    .PARAMETER Metadata
    Optional key-value metadata.
    #>
    param($Message, [hashtable]$Metadata = @{})
    Write-Log -Level 'CRITICAL' -NumericLevel 50 -Message $Message -Metadata $Metadata
}
