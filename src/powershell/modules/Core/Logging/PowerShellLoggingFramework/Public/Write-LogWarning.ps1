function Write-LogWarning {
    <#
    .SYNOPSIS
    Logs a message at WARNING level.
    .DESCRIPTION
    Writes a log entry with level WARNING (30).
    .PARAMETER Message
    The warning message to log.
    .PARAMETER Metadata
    Optional key-value metadata.
    #>
    param($Message, [hashtable]$Metadata = @{})
    Write-Log -Level 'WARNING' -NumericLevel 30 -Message $Message -Metadata $Metadata
}
