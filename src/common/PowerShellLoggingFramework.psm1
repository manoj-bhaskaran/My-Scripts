############################################################
# PowerShellLoggingFramework.psm1
# Logging module conforming to cross-platform specification
############################################################

$script:LogConfig = @{
    ScriptName   = $MyInvocation.MyCommand.Name
    LogLevel     = 20  # INFO by default
    LogFilePath  = $null
    JsonFormat   = $false  # Set to $true to enable JSON structured logging
    ConsoleOutput = 'OnError'  # Default: No console output unless specified
}

$script:RecommendedMetadataKeys = @("CorrelationId", "User", "TaskId", "FileName", "Duration")
$script:HasWarnedFileFailure = $false

function Initialize-Logger {
<#
.SYNOPSIS
    Initializes the logging framework for the current PowerShell script.

.DESCRIPTION
    Sets up module-scoped logging configuration including the log directory, log level, and script name.
    Ensures the log directory exists and determines the correct log file name based on the script
    and the current date, following the standardised logging specification.
    The default log directory is automatically resolved relative to the invoking script’s path 
    (not the module’s path), ensuring logs go to <script_root_dir>/logs in compliance with the 
    specification.

.PARAMETER LogDirectory
    The directory where log files should be written. If the directory does not exist, it will be created.
    If not specified, defaults to <script_root_dir>/logs, inferred from the caller's script path.

.PARAMETER ScriptName
    The name of the script generating the logs. If provided, spaces are replaced with underscores to comply
    with the logging specification. If not provided or empty, the name of the calling script (including its
    extension, e.g., 'caller.ps1') is used, derived from the call stack with spaces replaced by underscores.
    If the calling script cannot be determined, defaults to "unknown". The extension is stripped in the
    final log file name per the specification (e.g., 'caller_powershell_YYYY-MM-DD.log').

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

.PARAMETER ConsoleOutput
    Specifies console output behavior. Optional. Options:
        None    - Never write to console
        Always  - Write to both file and console
        OnError - Write to console only if file write fails (default)

.EXAMPLE
    Initialize-Logger -LogDirectory "D:\Logs" -ScriptName "backup.ps1" -LogLevel 10 -ConsoleOutput Always

    Initializes logging to D:\Logs\backup_powershell_YYYY-MM-DD.log with DEBUG level and console output always enabled.

.EXAMPLE
    Initialize-Logger

    Initializes logging to the default ../../logs folder using the current script name, INFO level, and no console output.

.NOTES
    Log files are created in the format: <script_name>_powershell_<YYYY-MM-DD>.log
    This function must be called before using any Write-Log* functions.
    When enabled, JSON logging includes keys: timestamp, level, script, host, pid, message, metadata.
#>
    param (
        [string]$LogDirectory = "$PSScriptRoot/../../logs",
        [ValidatePattern('^[^<>:\/\\|?*\s]+$')]
        [string]$ScriptName = "",
        [ValidateSet(10, 20, 30, 40, 50)]
        [int]$LogLevel = 20,
        [switch]$JsonFormat,
        [ValidateSet('None', 'Always', 'OnError')]
        [string]$ConsoleOutput = 'OnError'
    )

    $script:LogConfig.LogLevel = $LogLevel
    $script:LogConfig.JsonFormat = $JsonFormat.IsPresent
    $script:LogConfig.ConsoleOutput = $ConsoleOutput
    $callerScriptPath = (Get-PSCallStack)[1].ScriptName
    $script:LogConfig.ScriptName = if ($ScriptName) { 
        $ScriptName -replace '\s+', '_'
    } else {
        if ($callerScriptPath) { 
            ([IO.Path]::GetFileName($callerScriptPath)) -replace '\s+', '_'
        } else { 
            "unknown" 
        }
    }
    $callerScriptRoot = Split-Path -Path $callerScriptPath -Parent
    $LogDirectory = if ($LogDirectory) { $LogDirectory } else { Join-Path (Split-Path $callerScriptRoot -Parent) "logs" }
    $script:LogConfig.LogDirectory = $LogDirectory
    $script:HasWarnedFileFailure = $false

    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $dateStr = (Get-Date -Format 'yyyy-MM-dd')
    $scriptBase = [IO.Path]::GetFileNameWithoutExtension($script:LogConfig.ScriptName)
    $logFile = Join-Path $LogDirectory "${scriptBase}_powershell_$dateStr.log"

    $script:LogConfig.LogFilePath = $logFile
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
        "UTC"                 { return "UTC" }
        default               { return $tz.StandardName }
    }
}

$script:RecommendedMetadataKeys = @("CorrelationId", "User", "TaskId", "FileName", "Duration", "DryRun", "TotalLines", "PurgedLines", "Retained", "FinalSizeMB", "CurrentSizeMB", "ThresholdMB")

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
        if ($script:RecommendedMetadataKeys -notcontains $key) {
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
    falls back to console output if file writing fails.
    If JSON format is enabled, logs are written as compressed single-line JSON for structured ingestion.
    If writing to the log file fails (e.g., due to permissions or disk space), a warning is issued via 
    Write-Warning, and the log is written to the console as a fallback.

.PARAMETER NumericLevel
    The numeric representation of the log level. Valid values:
        10 - DEBUG
        20 - INFO
        30 - WARNING
        40 - ERROR
        50 - CRITICAL
    The textual level (e.g., 'INFO') is derived from this value for log output.

.PARAMETER Message
    The message to include in the log entry.

.PARAMETER Metadata
    Optional hashtable of key-value metadata pairs to append to the log entry.

.NOTES
    Should not be called directly; use Write-LogInfo, Write-LogError, etc.
    Optional metadata is validated against a recommended list. A warning is shown if an unrecognized 
    key is used.
    The log level text (e.g., 'INFO', 'ERROR') is derived from NumericLevel to ensure consistency.
#>
    param (
        [ValidateSet(10, 20, 30, 40, 50)]
        [int]$NumericLevel,
        [string]$Message,
        [hashtable]$Metadata = @{}
    )

    if ($NumericLevel -lt $script:LogConfig.LogLevel) {
        return
    }

    $Level = switch ($NumericLevel) {
        10 { 'DEBUG' }
        20 { 'INFO' }
        30 { 'WARNING' }
        40 { 'ERROR' }
        50 { 'CRITICAL' }
        default { throw "Invalid NumericLevel: $NumericLevel" }
    }

    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") + " " + (Get-TimezoneAbbreviation)
    $scriptName = $script:LogConfig.ScriptName
    $hostName = $env:COMPUTERNAME
    $metaStr = if ($Metadata.Count -gt 0) {
        Test-MetadataKeys -Metadata $Metadata
        $Metadata.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } -join ' '
    } else {
        ""
    }

    if ($script:LogConfig.JsonFormat) {
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
    } else {
        $logLine = "[${timestamp}] [$Level] [$scriptName] [$hostName] [$PID] $Message"
        if ($metaStr) { $logLine += " [$metaStr]" }
    }

   $writeToConsole = $false
    try {
        Add-Content -Path $script:LogConfig.LogFilePath -Value $logLine -Encoding UTF8
    } catch {
        if (-not $script:HasWarnedFileFailure) {
            Write-Warning "Failed to write to log file '$($script:LogConfig.LogFilePath)': $_"
            $script:HasWarnedFileFailure = $true
        }
        if ($script:LogConfig.ConsoleOutput -in 'OnError', 'Always') {
            $writeToConsole = $true
        }
    }

    if ($script:LogConfig.ConsoleOutput -eq 'Always' -or $writeToConsole) {
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
    Write-Log -NumericLevel 10 -Message $Message -Metadata $Metadata
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
    Write-Log -NumericLevel 20 -Message $Message -Metadata $Metadata
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
    Write-Log -NumericLevel 30 -Message $Message -Metadata $Metadata
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
    Write-Log -NumericLevel 40 -Message $Message -Metadata $Metadata
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
    Write-Log -NumericLevel 50 -Message $Message -Metadata $Metadata
}