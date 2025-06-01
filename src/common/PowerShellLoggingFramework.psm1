############################################################
# PowerShellLoggingFramework.psm1
# Logging module conforming to cross-platform specification
############################################################

$Global:LogConfig = @{
    LogDirectory = "$PSScriptRoot/../../logs"
    ScriptName   = $MyInvocation.MyCommand.Name
    LogLevel     = 20  # INFO by default
    LogFilePath  = $null
}

function Initialize-Logger {
<#
.SYNOPSIS
    Initializes the logging framework for the current PowerShell script.

.DESCRIPTION
    Sets up global logging configuration including the log directory, log level, and script name.
    Ensures the log directory exists and determines the correct log file name based on the script
    and the current date, following the standardised logging specification.

.PARAMETER LogDirectory
    The directory where log files should be written. If the directory does not exist, it will be created.
    Default is '../../logs' relative to the module location.

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

.EXAMPLE
    Initialize-Logger -LogDirectory "D:\Logs" -ScriptName "backup.ps1" -LogLevel 10

    Initializes logging to D:\Logs\backup_powershell_YYYY-MM-DD.log with DEBUG level.

.EXAMPLE
    Initialize-Logger

    Initializes logging to the default ../../logs folder using the current script name and INFO level.

.NOTES
    Log files are created in the format: <script_name>_powershell_<YYYY-MM-DD>.log
    This function must be called before using any Write-Log* functions.
#>
    param (
        [string]$LogDirectory = "$PSScriptRoot/../../logs",
        [string]$ScriptName = $null,
        [int]$LogLevel = 20
    )

    $Global:LogConfig.LogLevel = $LogLevel
    $Global:LogConfig.ScriptName = if ($ScriptName) { $ScriptName } else { $MyInvocation.ScriptName }

    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $dateStr = (Get-Date -Format 'yyyy-MM-dd')
    $scriptBase = [IO.Path]::GetFileNameWithoutExtension($Global:LogConfig.ScriptName)
    $logFile = Join-Path $LogDirectory "${scriptBase}_powershell_$dateStr.log"

    $Global:LogConfig.LogFilePath = $logFile
}

function Write-Log {
<#
.SYNOPSIS
    Writes a formatted log entry to the log file or console.

.DESCRIPTION
    Formats a log entry based on timestamp, level, script name, host, process ID,
    message, and optional metadata. Writes to the configured log file or
    falls back to standard output if file writing fails.

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

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff zzz"
    $scriptName = $Global:LogConfig.ScriptName
    $hostName = $env:COMPUTERNAME
    $metaStr = if ($Metadata.Count -gt 0) {
        $Metadata.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } -join ' '
    } else {
        ""
    }

    $logLine = "[${timestamp}] [$Level] [$scriptName] [$hostName] [$PID] $Message"
    if ($metaStr) { $logLine += " [$metaStr]" }

    try {
        Add-Content -Path $Global:LogConfig.LogFilePath -Value $logLine -Encoding UTF8
    } catch {
        Write-Output $logLine
    }
}

function Write-LogDebug {
<#
.SYNOPSIS
    Logs a message at DEBUG level.
.DESCRIPTION
    Writes a log entry with level DEBUG (10).
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
