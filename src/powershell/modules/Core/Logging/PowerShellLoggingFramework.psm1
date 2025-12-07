############################################################
# PowerShellLoggingFramework.psm1
# Logging module conforming to cross-platform specification
############################################################

$Global:LogConfig = @{
    ScriptName  = $MyInvocation.MyCommand.Name
    LogLevel    = 20  # INFO by default
    LogFilePath = $null
    JsonFormat  = $false  # Set to $true to enable JSON structured logging
}

$Global:RecommendedMetadataKeys = @("CorrelationId", "User", "TaskId", "FileName", "Duration")
$script:DefaultLogDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "logs"

function Initialize-Logger {
    <#
.SYNOPSIS
    Initializes the logging framework for the current PowerShell script.

.DESCRIPTION
    Sets up global logging configuration including the log directory, log level, and script name.
    Ensures the log directory exists and determines the correct log file name based on the script
    and the current date, following the standardised logging specification.
    The default log directory is resolved once when the module loads (../../logs relative to the
    module path) to avoid repeated path calculations. If a null directory is explicitly passed in,
    the logger falls back to deriving a logs folder adjacent to the calling script.

.PARAMETER LogDirectory
    The directory where log files should be written. If the directory does not exist, it will be created.
    If not specified, defaults to the module's precomputed logs directory, avoiding repeated path resolution.

.PARAMETER ScriptName
    The name of the script generating the logs. If not provided, the invoking script's name is used.

.PARAMETER LogLevel
    Numeric log level to control which log messages are written. Lower values include more detail.
    Allowed values:
        10 - DEBUG
        20 - INFO (default)
        30 - WARNING
        40 - ERROR
        50 - CRITICAL

.PARAMETER JsonFormat
    Switch to enable JSON structured logging instead of plain-text format.
    If $true, log entries will be output as single-line JSON objects per log line.

.EXAMPLE
    Initialize-Logger -LogDirectory "D:\Logs" -ScriptName "backup.ps1" -LogLevel 10

    Initializes logging to D:\Logs\backup_powershell_YYYY-MM-DD.log with DEBUG level.

.EXAMPLE
    Initialize-Logger

    Initializes logging to the default ../../logs folder using the current script name and INFO level.

.NOTES
    Log files are created in the format: <script_name>_powershell_<YYYY-MM-DD>.log
    This function must be called before using any Write-Log* functions.
    When enabled, JSON logging includes keys: timestamp, level, script, host, pid, message, metadata.
#>
    param (
        [string]$resolvedLogDir = $script:DefaultLogDir,
        [string]$ScriptName = $null,
        [int]$LogLevel = 20
    )

    $Global:LogConfig.LogLevel = $LogLevel
    $Global:LogConfig.ScriptName = if ($ScriptName) { $ScriptName } else { $MyInvocation.ScriptName }

    if (-not $resolvedLogDir) {
        $callerScriptPath = (Get-PSCallStack)[1].ScriptName
        if ($callerScriptPath) {
            $callerScriptRoot = Split-Path -Path $callerScriptPath -Parent
            $resolvedLogDir = Join-Path (Split-Path $callerScriptRoot -Parent) "logs"
        }
        else {
            $resolvedLogDir = $script:DefaultLogDir
        }
    }

    $Global:LogConfig.LogDirectory = $resolvedLogDir


    # Ensure the log directory exists, creating parent directories as needed
    if (-not (Test-Path $resolvedLogDir)) {
        try {
            New-Item -Path $resolvedLogDir -ItemType Directory -Force | Out-Null
        }
        catch {
            Write-Warning "Failed to create log directory '$resolvedLogDir': $_"
            throw
        }
    }

    $dateStr = (Get-Date -Format 'yyyy-MM-dd')
    $scriptBase = [IO.Path]::GetFileNameWithoutExtension($Global:LogConfig.ScriptName)
    $logFile = Join-Path $resolvedLogDir "${scriptBase}_powershell_$dateStr.log"

    $Global:LogConfig.LogFilePath = $logFile
}
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
        # Ensure the log file's directory exists before writing
        $logFileDir = Split-Path -Path $Global:LogConfig.LogFilePath -Parent
        if ($logFileDir -and -not (Test-Path $logFileDir)) {
            New-Item -Path $logFileDir -ItemType Directory -Force | Out-Null
        }
        
        Add-Content -Path $Global:LogConfig.LogFilePath -Value $logLine -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write to log file '$($Global:LogConfig.LogFilePath)': $_"
        Write-Output $logLine
    }
}

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
