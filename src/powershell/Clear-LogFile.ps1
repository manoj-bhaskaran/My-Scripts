<#
.SYNOPSIS
    CLI wrapper for log cleanup using the Clear-LogFile cmdlet.

.DESCRIPTION
    This script serves as a command-line interface to the Clear-LogFile function
    defined in the PurgeLogs module. It supports four mutually exclusive cleanup
    strategies, applied in the following precedence:

        1. RetentionDays       – removes entries older than N days
        2. MaxSizeMB           – trims log file to fit within size
        3. TruncateIfLarger    – clears file if size exceeds threshold
        4. TruncateLog         – unconditional truncation

    Only one strategy is applied per invocation. All activity is logged
    according to the PowerShellLoggingFramework.psm1 specification.

.PARAMETER LogFilePath
    Full path to the log file to be purged.

.PARAMETER RetentionDays
    Retention policy in days. Removes lines with timestamps older than this value.

.PARAMETER MaxSizeMB
    Trims the log file to keep only the most recent data within this size in MB.

.PARAMETER TruncateIfLarger
    Truncates the log file if its current size exceeds the specified threshold (e.g. "500MB").

.PARAMETER TruncateLog
    Clears the log file entirely.

.PARAMETER DryRun
    Simulates purge without modifying the log file. Still logs the simulated result.

.PARAMETER Verbose
    Enables verbose output for troubleshooting.

.EXAMPLE
    .\purge_logs.ps1 -LogFilePath "C:\logs\job.log" -RetentionDays 15 -Verbose

.EXAMPLE
    .\purge_logs.ps1 -LogFilePath "C:\logs\job.log" -MaxSizeMB 20

.EXAMPLE
    .\purge_logs.ps1 -LogFilePath "C:\logs\job.log" -TruncateIfLarger "250MB"

.EXAMPLE
    .\purge_logs.ps1 -LogFilePath "C:\logs\job.log" -TruncateLog

.NOTES
    This script requires the PurgeLogs.psm1 module to be located in ../src/common/
#>

param (
    [string]$LogFilePath,
    [int]$RetentionDays,
    [int]$MaxSizeMB,
    [string]$TruncateIfLarger,
    [switch]$TruncateLog,
    [switch]$DryRun,
    [switch]$Verbose
)

Import-Module "$PSScriptRoot/../src/common/PurgeLogs.psm1" -Force
Clear-LogFile @PSBoundParameters
