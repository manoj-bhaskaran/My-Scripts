$Global:LogConfig = @{
    ScriptName  = $MyInvocation.MyCommand.Name
    LogLevel    = 20  # INFO by default
    LogFilePath = $null
    JsonFormat  = $false  # Set to $true to enable JSON structured logging
}

$Global:RecommendedMetadataKeys = @("CorrelationId", "User", "TaskId", "FileName", "Duration")

function Get-TimezoneAbbreviation {
    <#
    .SYNOPSIS
    Returns the current system timezone abbreviation (e.g., IST, UTC).

    .DESCRIPTION
    Resolves the system's local timezone to a commonly used abbreviation.
    PowerShell's built-in date formatting provides numeric offsets (e.g., +05:30),
    but this function maps the system's timezone ID to a human-readable abbreviation
    for use in logs that require strict adherence to the specification.

    Currently supports hardcoded mappings for known timezones (e.g., IST, UTC).
    If the local timezone is not explicitly handled, the full standard name is returned as a fallback.

    .EXAMPLE
    Get-TimezoneAbbreviation
    Output: IST

    Returns the abbreviation for the current system timezone.

    .NOTES
    Expand the switch block for broader support of additional timezones as needed.
    Used by the logging framework to format timestamps per specification.

    #>
    $tz = [System.TimeZoneInfo]::Local
    switch ($tz.Id) {
        "India Standard Time" { return "IST" }
        "UTC" { return "UTC" }
        default { return $tz.StandardName }
    }
}

function Test-MetadataKeys {
    <#
    .SYNOPSIS
    Tests metadata keys against the recommended standard list and warns on non-standard keys.
    .DESCRIPTION
    Checks user-provided metadata against the standard list of recommended keys
    and emits warnings for unrecognized keys.
    .PARAMETER Metadata
    The hashtable of metadata passed to a log function.
    #>
    param([hashtable]$Metadata)

    foreach ($key in $Metadata.Keys) {
        if ($Global:RecommendedMetadataKeys -notcontains $key) {
            Write-Warning "Unrecognized metadata key: '$key'. Consider standardizing it if applicable."
        }
    }
}

function Write-Log {
    <#
    .SYNOPSIS
    Writes a formatted log entry to the log file or console.

    .DESCRIPTION
    Formats a log entry based on timestamp, level, script name, host, process ID,
    message, and optional metadata. Writes to the configured log file or
    falls back to standard output if file writing fails.
    If JSON format is enabled, logs are written as compressed single-line JSON for structured ingestion.
    If writing to the log file fails (e.g., due to permissions or disk space), a warning is issued via
    Write-Warning, and the log is written to the console as a fallback.

    .PARAMETER Level
    The textual name of the log level (e.g., INFO, ERROR).

    .PARAMETER NumericLevel
    The numeric representation of the log level.

    .PARAMETER Message
    The message to include in the log entry.

    .PARAMETER Metadata
    Optional hashtable of key-value metadata pairs to append to the log entry.

    .NOTES
    Should not be called directly; use Write-LogInfo, Write-LogError, etc.
    Optional metadata is validated against a recommended list. A warning is shown if an unrecognized
    key is used.
    #>
    param (
        [string]$Level,
        [int]$NumericLevel,
        [string]$Message,
        [hashtable]$Metadata = @{}
    )

    if ($NumericLevel -lt $Global:LogConfig.LogLevel) {
        return
    }

    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") + " " + (Get-TimezoneAbbreviation)
    $scriptName = $Global:LogConfig.ScriptName
    $hostName = $env:COMPUTERNAME
    $metaStr = if ($Metadata.Count -gt 0) {
        Test-MetadataKeys -Metadata $Metadata
        $Metadata.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } -join ' '
    }
    else {
        ""
    }

    if ($Global:LogConfig.JsonFormat) {
        $logObject = [PSCustomObject]@{
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
            level     = $Level
            script    = $scriptName
            host      = $hostName
            pid       = $PID
            message   = $Message
            metadata  = $Metadata
        }
        $logLine = $logObject | ConvertTo-Json -Depth 5 -Compress
    }
    else {
        $logLine = "[${timestamp}] [$Level] [$scriptName] [$hostName] [$PID] $Message"
        if ($metaStr) { $logLine += " [$metaStr]" }
    }

    try {
        Add-Content -Path $Global:LogConfig.LogFilePath -Value $logLine -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write to log file '$($Global:LogConfig.LogFilePath)': $_"
        Write-Output $logLine
    }
}
