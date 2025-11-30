function Clear-LogFile {
    <#
    .SYNOPSIS
    Applies retention or size-based log purging logic to a log file.

    .DESCRIPTION
    Purges a log file by one of four mutually exclusive strategies, in this order:
    1. RetentionDays: removes entries older than N days
    2. MaxSizeMB: trims log from the start to fit in limit
    3. TruncateIfLarger: clears file if it exceeds specified size
    4. TruncateLog: clears file unconditionally

    The log file must follow the standard format: timestamped lines starting with
    [YYYY-MM-DD HH:MM:SS[.fff] TIMEZONE].

    .PARAMETER LogFilePath
    Path to the log file to purge.

    .PARAMETER RetentionDays
    Remove log entries older than N days.

    .PARAMETER MaxSizeMB
    Retain only as many lines as fit within the given size in MB.

    .PARAMETER TruncateIfLarger
    Truncate the log file completely if its size exceeds this value.

    .PARAMETER TruncateLog
    Clear the log file unconditionally.

    .PARAMETER DryRun
    Do not perform any changes, but simulate the operation.

    .PARAMETER Verbose
    Emit verbose output via logging framework.

    .NOTES
    - Only one strategy is applied per run
    - If none of the parameters are specified, no action is taken
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string]$LogFilePath,

        [int]$RetentionDays,
        [int]$MaxSizeMB,
        [string]$TruncateIfLarger,
        [switch]$TruncateLog,
        [switch]$DryRun
    )

    if (!(Test-Path $LogFilePath)) {
        throw "Log file not found: $LogFilePath"
    }

    $verboseSet = $PSCmdlet.MyInvocation.BoundParameters['Verbose']
    Initialize-Logger -ScriptName "purge_logs.ps1" -Verbose:$verboseSet

    # Validate
    if ($PSBoundParameters.ContainsKey("RetentionDays") -and $RetentionDays -lt 0) {
        throw "RetentionDays cannot be negative"
    }
    if ($PSBoundParameters.ContainsKey("MaxSizeMB") -and $MaxSizeMB -lt 0) {
        throw "MaxSizeMB cannot be negative"
    }
    if ($TruncateIfLarger) {
        $thresholdBytes = ConvertTo-Bytes -Size $TruncateIfLarger
        if ($thresholdBytes -lt 0) {
            throw "TruncateIfLarger must be non-negative"
        }
    }

    # RetentionDays strategy
    if ($PSBoundParameters.ContainsKey("RetentionDays")) {
        Write-LogMessage -Level "INFO" -Message "Applying RetentionDays strategy" -Metadata @{
            RetentionDays = $RetentionDays
            FileName      = $LogFilePath
        }

        $cutoff = (Get-Date).AddDays(-$RetentionDays)
        $timestampRegex = '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?(?: [A-Z]+)?)\]'
        $retainedLines = [System.Collections.Generic.List[string]]::new()
        $lineCount = 0
        $purgedCount = 0

        try {
            Get-Content -Path $LogFilePath -Encoding UTF8 | ForEach-Object {
                $lineCount++
                if ($_ -match $timestampRegex) {
                    $timestamp = $matches[1]
                    try {
                        $parsed = [datetime]::ParseExact($timestamp, "yyyy-MM-dd HH:mm:ss.fff zzz", $null)
                        if ($parsed -lt $cutoff) {
                            $purgedCount++
                            return
                        }
                    }
                    catch {}
                }
                $retainedLines.Add($_)
            }
        }
        catch {
            Write-LogMessage -Level "ERROR" -Message "Failed to read log file: $($_.Exception.Message)" -Metadata @{ FileName = $LogFilePath }
            return
        }

        if (-not $DryRun -and $PSCmdlet.ShouldProcess($LogFilePath, "Write filtered log lines")) {
            try {
                $retainedLines | Set-Content -Path $LogFilePath -Encoding UTF8
            }
            catch {
                Write-LogMessage -Level "ERROR" -Message "Failed to write updated log: $($_.Exception.Message)" -Metadata @{ FileName = $LogFilePath }
                return
            }
        }

        Write-LogMessage -Level "INFO" -Message "Retention purge completed" -Metadata @{
            FileName    = $LogFilePath
            TotalLines  = $lineCount
            PurgedLines = $purgedCount
            Retained    = $retainedLines.Count
            FinalSizeMB = [math]::Round([System.Text.Encoding]::UTF8.GetByteCount($retainedLines -join "`n") / 1MB, 2)
            DryRun      = $DryRun.IsPresent
        }
        return
    }

    # MaxSizeMB strategy
    elseif ($PSBoundParameters.ContainsKey("MaxSizeMB")) {
        Write-LogMessage -Level "INFO" -Message "Applying MaxSizeMB strategy" -Metadata @{
            MaxSizeMB = $MaxSizeMB
            FileName  = $LogFilePath
        }

        $maxBytes = [long]($MaxSizeMB * 1MB)
        try {
            $lines = Get-Content $LogFilePath
        }
        catch {
            Write-LogMessage -Level "ERROR" -Message "Failed to read file: $($_.Exception.Message)" -Metadata @{ FileName = $LogFilePath }
            return
        }

        $lines = [System.Collections.Generic.List[string]]::new($lines)
        $lines.Reverse()
        $size = 0
        $trimmed = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $lines) {
            $lineBytes = [System.Text.Encoding]::UTF8.GetByteCount($line) + [System.Text.Encoding]::UTF8.GetByteCount("`n")
            if ($size + $lineBytes -gt $maxBytes) { break }
            $trimmed.Add($line)
            $size += $lineBytes
        }
        $trimmed.Reverse()

        if (-not $DryRun -and $PSCmdlet.ShouldProcess($LogFilePath, "Write trimmed log lines")) {
            try {
                $trimmed | Set-Content $LogFilePath -Encoding UTF8
            }
            catch {
                Write-LogMessage -Level "ERROR" -Message "Failed to write trimmed file: $($_.Exception.Message)" -Metadata @{ FileName = $LogFilePath }
                return
            }
        }

        Write-LogMessage -Level "WARNING" -Message "Log file trimmed to fit MaxSizeMB" -Metadata @{
            FileName      = $LogFilePath
            RetainedLines = $trimmed.Count
            FinalSizeMB   = [math]::Round($size / 1MB, 2)
            DryRun        = $DryRun.IsPresent
        }
        return
    }

    # TruncateIfLarger strategy
    elseif ($TruncateIfLarger) {
        $currentSize = (Get-Item $LogFilePath).Length
        if ($currentSize -gt $thresholdBytes) {
            if (-not $DryRun -and $PSCmdlet.ShouldProcess($LogFilePath, "Clear log file due to size")) {
                try {
                    Clear-Content -Path $LogFilePath -Force
                }
                catch {
                    Write-LogMessage -Level "ERROR" -Message "Truncate failed: $($_.Exception.Message)" -Metadata @{ FileName = $LogFilePath }
                    return
                }
            }
            Write-LogMessage -Level "WARNING" -Message "Log file truncated due to size threshold" -Metadata @{
                FileName      = $LogFilePath
                CurrentSizeMB = [math]::Round($currentSize / 1MB, 2)
                ThresholdMB   = [math]::Round($thresholdBytes / 1MB, 2)
                DryRun        = $DryRun.IsPresent
            }
        }
        else {
            Write-LogMessage -Level "INFO" -Message "No truncation needed; file under threshold" -Metadata @{
                FileName      = $LogFilePath
                CurrentSizeMB = [math]::Round($currentSize / 1MB, 2)
                ThresholdMB   = [math]::Round($thresholdBytes / 1MB, 2)
            }
        }
        return
    }

    # TruncateLog strategy
    elseif ($TruncateLog) {
        if (-not $DryRun -and $PSCmdlet.ShouldProcess($LogFilePath, "Clear entire log file")) {
            try {
                Clear-Content -Path $LogFilePath -Force
            }
            catch {
                Write-LogMessage -Level "ERROR" -Message "Failed to truncate log file: $($_.Exception.Message)" -Metadata @{ FileName = $LogFilePath }
                return
            }
        }
        Write-LogMessage -Level "WARNING" -Message "Log file forcefully truncated" -Metadata @{
            FileName = $LogFilePath
            DryRun   = $DryRun.IsPresent
        }
        return
    }

    # Nothing matched
    Write-LogMessage -Level "INFO" -Message "No strategy applied. No valid parameters specified." -Metadata @{ FileName = $LogFilePath }
}
