function Write-LogInfo {
    <#
    .SYNOPSIS
    Logs a message at INFO level.
    .DESCRIPTION
    Writes a log entry with level INFO (20).
    .PARAMETER Message
    The info message to log.
    .PARAMETER Metadata
    Optional key-value metadata.
    #>
    param($Message, [hashtable]$Metadata = @{})
    Write-Log -Level 'INFO' -NumericLevel 20 -Message $Message -Metadata $Metadata
}
