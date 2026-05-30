function Initialize-Logger {
    <#
.SYNOPSIS
Initializes the logging framework for the current PowerShell script.

.DESCRIPTION
Sets up global logging configuration including the log directory, log level, and script name.
Ensures the log directory exists and determines the correct log file name based on the script
and the current date, following the standardised logging specification.
The default log directory is automatically resolved relative to the invoking script’s path
(not the module’s path), ensuring logs go to <script_root_dir>/logs in compliance with the
specification.

.PARAMETER LogDirectory
The directory where log files should be written. If the directory does not exist, it will be created.
If not specified, defaults to <script_root_dir>/logs, inferred from the caller's script path.

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
Initialize-Logger -LogDirectory "D:\\Logs" -ScriptName "backup.ps1" -LogLevel 10

Initializes logging to D:\\Logs\\backup_powershell_YYYY-MM-DD.log with DEBUG level.

.EXAMPLE
Initialize-Logger

Initializes logging to the default ../../logs folder using the current script name and INFO level.

.NOTES
Log files are created in the format: <script_name>_powershell_<YYYY-MM-DD>.log
This function must be called before using any Write-Log* functions.
When enabled, JSON logging includes keys: timestamp, level, script, host, pid, message, metadata.
#>
    param (
        [Parameter(Mandatory = $false)]
        [Alias('resolvedLogDir')]
        [string]$LogDirectory = (Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'logs'),

        [string]$ScriptName = $null,
        [int]$LogLevel = 20
    )

    $Global:LogConfig.LogLevel = $LogLevel
    $Global:LogConfig.ScriptName = if ($ScriptName) { $ScriptName } else { $MyInvocation.ScriptName }

    $resolvedLogDir = $LogDirectory
    if ([string]::IsNullOrWhiteSpace($resolvedLogDir)) {
        $callerScriptPath = (Get-PSCallStack)[1].ScriptName
        if ($callerScriptPath) {
            $callerScriptRoot = Split-Path -Path $callerScriptPath -Parent
            $resolvedLogDir = Join-Path (Split-Path $callerScriptRoot -Parent) "logs"
        } else {
            $resolvedLogDir = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'logs'
        }
    }

    try {
        $resolvedLogDir = [System.IO.Path]::GetFullPath($resolvedLogDir)
    } catch {
        throw "Invalid log directory '$resolvedLogDir': $($_.Exception.Message)"
    }

    $Global:LogConfig.LogDirectory = $resolvedLogDir

    if (-not (Test-Path -LiteralPath $resolvedLogDir)) {
        [System.IO.Directory]::CreateDirectory($resolvedLogDir) | Out-Null
    }

    $dateStr = (Get-Date -Format 'yyyy-MM-dd')
    $scriptBase = [IO.Path]::GetFileNameWithoutExtension($Global:LogConfig.ScriptName)
    $logFile = Join-Path -Path $resolvedLogDir -ChildPath "${scriptBase}_powershell_$dateStr.log"

    $Global:LogConfig.LogFilePath = $logFile
}
