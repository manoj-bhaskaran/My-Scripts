<#
.SYNOPSIS
    Centralised log file purging utility compliant with standard logging specification.

.DESCRIPTION
    This script performs log file cleanup based on one of the following precedence-based strategies:
    1. Time-based retention (-RetentionDays): Deletes entries older than specified days.
    2. Size-based trimming (-MaxSizeMB): Retains most recent lines to stay within size limit.
    3. Conditional truncation (-TruncateIfLarger): Truncates entire file if size exceeds threshold.
    4. Force truncation (-TruncateLog): Clears the file unconditionally.

    Only one strategy is applied per run, based on the order above. Remaining parameters are ignored.
    All actions are logged using a shared logging framework (PowerShellLoggingFramework.psm1).

.PARAMETER LogFilePath
    Fully qualified path to the log file to be purged.

.PARAMETER RetentionDays
    Time-based retention cutoff in days. If specified (>= 0), all older log entries are removed.

.PARAMETER MaxSizeMB
    Size threshold in megabytes. If specified and RetentionDays is not, keeps only the most recent log lines to stay under this limit.

.PARAMETER TruncateIfLarger
    Size string (e.g., 200MB, 100KB). If specified and the log file exceeds this size, it will be cleared entirely.

.PARAMETER TruncateLog
    If specified, truncates the file unconditionally. Used as the last resort in the precedence order.

.PARAMETER DryRun
    Optional switch. If used, no changes are written to disk; operations are logged only.

.PARAMETER Verbose
    Optional switch. Enables verbose logging output.

.NOTES
    - Logging format complies with Cross-Platform Logging Specification
    - Requires PowerShellLoggingFramework.psm1 in the same directory
    - Use scheduled task or manual invocation

.EXAMPLE
    .\purge_logs.ps1 -LogFilePath "D:\Logs\job.log" -RetentionDays 15 -Verbose

.EXAMPLE
    .\purge_logs.ps1 -LogFilePath "C:\logs\script.log" -MaxSizeMB 10

.EXAMPLE
    .\purge_logs.ps1 -LogFilePath "C:\logs\script.log" -TruncateIfLarger "250MB"

.EXAMPLE
    .\purge_logs.ps1 -LogFilePath "C:\logs\script.log" -TruncateLog
#>

param (
    [string]$LogFilePath,
    [int]$RetentionDays = 30,
    [int]$MaxSizeMB = 500,
    [switch]$DryRun,
    [switch]$Verbose,
    [string]$TruncateIfLarger,
    [switch]$TruncateLog
)

$modulePath = Join-Path $PSScriptRoot "PowerShellLoggingFramework.psm1"
if (!(Get-Module -Name PowerShellLoggingFramework) -and (Test-Path $modulePath)) {
    Import-Module $modulePath -Force
} elseif (!(Get-Module -Name PowerShellLoggingFramework)) {
    Write-Error "Logging module not found: $modulePath"
    exit 1
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-PurgeLogFile -LogFilePath $LogFilePath -RetentionDays $RetentionDays -MaxSizeMB $MaxSizeMB `
        -DryRun:$DryRun -Verbose:$Verbose -TruncateIfLarger $TruncateIfLarger -TruncateLog:$TruncateLog
}

<#
.SYNOPSIS
    Internal entry point for log purging logic.

.DESCRIPTION
    This function executes the core purge strategy using the provided arguments.
    It is invoked automatically when the script is executed directly, or can be called
    manually if the script is dot-sourced.

    The following precedence determines the cleanup strategy:
    RetentionDays > MaxSizeMB > TruncateIfLarger > TruncateLog

    Logging output conforms to the PowerShellLoggingFramework.psm1 standard.

.NOTES
    Only use directly if this script is dot-sourced or included from another script.
#>
function Invoke-PurgeLogFile {
    param (
        [string]$LogFilePath,
        [int]$RetentionDays,
        [int]$MaxSizeMB,
        [switch]$DryRun,
        [switch]$Verbose,
        [string]$TruncateIfLarger,
        [switch]$TruncateLog
    )

    $scriptName = "purge_logs.ps1"
    Initialize-Logger -ScriptName $scriptName -Verbose:$Verbose

    if (!(Test-Path $LogFilePath)) {
        Write-LogMessage -Level "ERROR" -Message "Log file not found" -Metadata @{ FileName = $LogFilePath }
        return
    }

    # Validation
    if ($PSBoundParameters.ContainsKey("RetentionDays") -and $RetentionDays -lt 0) {
        Write-LogMessage -Level "ERROR" -Message "RetentionDays cannot be negative" -Metadata @{ Value = $RetentionDays }
        return
    }
    if ($PSBoundParameters.ContainsKey("MaxSizeMB") -and $MaxSizeMB -lt 0) {
        Write-LogMessage -Level "ERROR" -Message "MaxSizeMB cannot be negative" -Metadata @{ Value = $MaxSizeMB }
        return
    }
    if ($TruncateIfLarger) {
        try {
            $thresholdBytes = ConvertTo-Bytes -Size $TruncateIfLarger
            if ($thresholdBytes -lt 0) {
                Write-LogMessage -Level "ERROR" -Message "TruncateIfLarger must be non-negative" -Metadata @{ Value = $TruncateIfLarger }
                return
            }
        } catch {
            Write-LogMessage -Level "ERROR" -Message "Invalid TruncateIfLarger format: $($_.Exception.Message)" -Metadata @{ Value = $TruncateIfLarger }
            return
        }
    }

    # Strategy 1: RetentionDays
    if ($PSBoundParameters.ContainsKey("RetentionDays")) {
        Write-LogMessage -Level "INFO" -Message "Purging log file by RetentionDays" -Metadata @{ FileName = $LogFilePath; RetentionDays = $RetentionDays }

        $cutoff = (Get-Date).AddDays(-$RetentionDays)
        $timestampRegex = '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?(?: [A-Z]+)?)\]'
        $retainedLines = @()
        $purgedCount = 0
        $lineCount = 0

        Get-Content $LogFilePath | ForEach-Object {
            $line = $_
            $lineCount++
            if ($line -match $timestampRegex) {
                $timestampStr = $matches[1]
                try {
                    $ts = [datetime]::ParseExact($timestampStr, "yyyy-MM-dd HH:mm:ss.fff zzz", $null)
                } catch {
                    try { $ts = [datetime]::Parse($timestampStr) } catch { $ts = $null }
                }
                if ($ts -and $ts -lt $cutoff) {
                    $purgedCount++
                    return
                }
            }
            $retainedLines += $line
        }

        if (-not $DryRun) {
            $retainedLines | Set-Content -Path $LogFilePath -Encoding UTF8
        }

        Write-LogMessage -Level "INFO" -Message "Retention purge completed" -Metadata @{
            FileName     = $LogFilePath
            TotalLines   = $lineCount
            PurgedLines  = $purgedCount
            Retained     = $retainedLines.Count
            FinalSizeMB  = [math]::Round(((Get-Item $LogFilePath).Length / 1MB), 2)
        }

    } elseif ($PSBoundParameters.ContainsKey("MaxSizeMB")) {
        $maxBytes = $MaxSizeMB * 1MB
        $lines = Get-Content $LogFilePath
        $currentBytes = [System.Text.Encoding]::UTF8.GetByteCount($lines -join "`n")

        if ($currentBytes -le $maxBytes) {
            Write-LogMessage -Level "INFO" -Message "Log file already within MaxSizeMB" -Metadata @{
                FileName = $LogFilePath
                SizeMB   = [math]::Round($currentBytes / 1MB, 2)
            }
            return
        }

        $retainedBytes = 0
        $retainedLines = @()
        foreach ($line in ($lines | [System.Collections.Generic.List[string]])) {
            $lineBytes = [System.Text.Encoding]::UTF8.GetByteCount("$line`n")
            if ($retainedBytes + $lineBytes > $maxBytes) { break }
            $retainedLines += $line
            $retainedBytes += $lineBytes
        }

        if (-not $DryRun) {
            $retainedLines | Set-Content -Path $LogFilePath -Encoding UTF8
        }

        Write-LogMessage -Level "WARNING" -Message "Log file trimmed by MaxSizeMB" -Metadata @{
            FileName    = $LogFilePath
            FinalSizeMB = [math]::Round($retainedBytes / 1MB, 2)
        }

    } elseif ($TruncateIfLarger) {
        $actualBytes = (Get-Item $LogFilePath).Length
        if ($actualBytes -gt $thresholdBytes) {
            if (-not $DryRun) {
                Clear-Content -Path $LogFilePath -Force
            }
            Write-LogMessage -Level "WARNING" -Message "Log file truncated by TruncateIfLarger" -Metadata @{
                FileName = $LogFilePath
                SizeMB   = [math]::Round($actualBytes / 1MB, 2)
            }
        } else {
            Write-LogMessage -Level "INFO" -Message "Log file under TruncateIfLarger threshold; no action taken" -Metadata @{
                FileName = $LogFilePath
                SizeMB   = [math]::Round($actualBytes / 1MB, 2)
            }
        }

    } elseif ($TruncateLog) {
        try {
            if (-not $DryRun) {
                Clear-Content -Path $LogFilePath -Force
            }
            Write-LogMessage -Level "WARNING" -Message "Log file forcefully truncated" -Metadata @{ FileName = $LogFilePath }
        } catch {
            Write-LogMessage -Level "ERROR" -Message "Failed to truncate log file: $($_.Exception.Message)" -Metadata @{ FileName = $LogFilePath }
        }

    } else {
        Write-LogMessage -Level "INFO" -Message "No action taken. No cleanup arguments provided." -Metadata @{ FileName = $LogFilePath }
    }
}

<#
.SYNOPSIS
    Converts a human-readable size string into an integer byte value.

.DESCRIPTION
    Accepts a string such as "100KB", "200MB", or "2GB" and returns the equivalent byte value.
    Throws an exception if the format is invalid.

.PARAMETER Size
    A size string in the format of a number followed by KB, MB, or GB (case-insensitive).

.EXAMPLE
    ConvertTo-Bytes -Size "100MB"

.NOTES
    Returns an integer value representing bytes.
#>
function ConvertTo-Bytes {
    param ([string]$Size)
    if ($Size -match '^([\d\.]+)([KMG]B)?$') {
        $value = [double]$matches[1]
        $unit = $matches[2].ToUpper()
        switch ($unit) {
            'KB' { return [int]($value * 1KB) }
            'MB' { return [int]($value * 1MB) }
            'GB' { return [int]($value * 1GB) }
            default { return [int]$value }
        }
    } else {
        throw "Invalid size format: $Size (e.g., 50MB, 100KB)"
    }
}
