function Write-LogError {
    <#
    .SYNOPSIS
    Logs a message at ERROR level.
    .DESCRIPTION
    Writes a log entry with level ERROR (40).
    .PARAMETER Message
    The error message to log.
    .PARAMETER Metadata
    Optional key-value metadata.
    #>
    param($Message, [hashtable]$Metadata = @{})
    Write-Log -Level 'ERROR' -NumericLevel 40 -Message $Message -Metadata $Metadata
}
