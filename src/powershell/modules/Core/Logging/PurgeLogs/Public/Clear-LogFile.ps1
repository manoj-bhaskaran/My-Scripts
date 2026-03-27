function Clear-LogFile {
    <#
.SYNOPSIS
    Applies retention or size-based log purging logic to a log file.

.DESCRIPTION
    Purges a log file with the following evaluation order:
    1. Timestamp filtering (`BeforeTimestamp` and/or `RetentionDays`)
    2. MaxSizeMB trimming (when supplied without timestamp filtering)
    3. TruncateIfLarger
    4. TruncateLog

    This preserves the historical FileDistributor behavior where retention filtering can be
    combined with truncation checks in one call.

.PARAMETER LogFilePath
    Path to the log file to purge.

.PARAMETER BeforeTimestamp
    Remove log entries before this timestamp.

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
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string]$LogFilePath,

        [datetime]$BeforeTimestamp,
        [int]$RetentionDays,
        [int]$MaxSizeMB,
        [string]$TruncateIfLarger,
        [switch]$TruncateLog,
        [switch]$DryRun
    )

    if (!(Test-Path -LiteralPath $LogFilePath)) {
        throw "Log file not found: $LogFilePath"
    }

    $verboseSet = $PSCmdlet.MyInvocation.BoundParameters['Verbose']
    Initialize-Logger -ScriptName "purge_logs.ps1" -Verbose:$verboseSet

    if ($PSBoundParameters.ContainsKey('RetentionDays') -and $RetentionDays -lt 0) {
        throw 'RetentionDays cannot be negative'
    }
    if ($PSBoundParameters.ContainsKey('MaxSizeMB') -and $MaxSizeMB -lt 0) {
        throw 'MaxSizeMB cannot be negative'
    }

    $hasBeforeTimestamp = $PSBoundParameters.ContainsKey('BeforeTimestamp')
    $hasRetentionDays = $PSBoundParameters.ContainsKey('RetentionDays')
    $hasMaxSizeMB = $PSBoundParameters.ContainsKey('MaxSizeMB')

    $thresholdBytes = $null
    if ($TruncateIfLarger) {
        $thresholdBytes = ConvertTo-Bytes -Size $TruncateIfLarger
        if ($thresholdBytes -lt 0) {
            throw 'TruncateIfLarger must be non-negative'
        }
    }

    $timestampRegex = '^\[?(?<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d{1,7})?)'
    $timestampFormats = @('yyyy-MM-dd HH:mm:ss','yyyy-MM-dd HH:mm:ss.fff','yyyy-MM-dd HH:mm:ss.fffffff')

    $applyTimestampFilter = $hasBeforeTimestamp -or $hasRetentionDays
    if ($applyTimestampFilter) {
        $cutoff = if ($hasRetentionDays) { (Get-Date).AddDays(-$RetentionDays) } else { $null }

        Write-LogMessage -Level 'INFO' -Message 'Applying timestamp filtering strategy' -Metadata @{
            FileName        = $LogFilePath
            BeforeTimestamp = if ($hasBeforeTimestamp) { $BeforeTimestamp.ToString('o') } else { $null }
            RetentionDays   = if ($hasRetentionDays) { $RetentionDays } else { $null }
        }

        $retainedLines = [System.Collections.Generic.List[string]]::new()
        $lineCount = 0
        $purgedCount = 0

        Get-Content -Path $LogFilePath -Encoding UTF8 | ForEach-Object {
            $lineCount++
            $line = $_
            $keepLine = $true

            if ($line -match $timestampRegex) {
                $parsedTimestamp = $null
                $capturedTimestamp = $matches['timestamp']
                if (-not [datetime]::TryParseExact($capturedTimestamp, $timestampFormats, $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsedTimestamp)) {
                    [void][datetime]::TryParse($capturedTimestamp, [ref]$parsedTimestamp)
                }

                if ($null -ne $parsedTimestamp) {
                    if ($hasBeforeTimestamp -and $parsedTimestamp -ge $BeforeTimestamp) {
                        $keepLine = $true
                    }
                    elseif ($hasRetentionDays -and $parsedTimestamp -ge $cutoff) {
                        $keepLine = $true
                    }
                    elseif ($hasBeforeTimestamp -or $hasRetentionDays) {
                        $keepLine = $false
                    }
                }
            }

            if ($keepLine) {
                $retainedLines.Add($line)
            }
            else {
                $purgedCount++
            }
        }

        if (-not $DryRun -and $PSCmdlet.ShouldProcess($LogFilePath, 'Write filtered log lines')) {
            $retainedLines | Set-Content -Path $LogFilePath -Encoding UTF8
        }

        Write-LogMessage -Level 'INFO' -Message 'Timestamp filtering completed' -Metadata @{
            FileName    = $LogFilePath
            TotalLines  = $lineCount
            PurgedLines = $purgedCount
            Retained    = $retainedLines.Count
            DryRun      = $DryRun.IsPresent
        }
    }
    elseif ($hasMaxSizeMB) {
        Write-LogMessage -Level 'INFO' -Message 'Applying MaxSizeMB strategy' -Metadata @{
            MaxSizeMB = $MaxSizeMB
            FileName  = $LogFilePath
        }

        $maxBytes = [long]($MaxSizeMB * 1MB)
        $lines = Get-Content $LogFilePath

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

        if (-not $DryRun -and $PSCmdlet.ShouldProcess($LogFilePath, 'Write trimmed log lines')) {
            $trimmed | Set-Content $LogFilePath -Encoding UTF8
        }

        Write-LogMessage -Level 'WARNING' -Message 'Log file trimmed to fit MaxSizeMB' -Metadata @{
            FileName      = $LogFilePath
            RetainedLines = $trimmed.Count
            FinalSizeMB   = [math]::Round($size / 1MB, 2)
            DryRun        = $DryRun.IsPresent
        }
    }

    if ($TruncateIfLarger) {
        $currentSize = (Get-Item -LiteralPath $LogFilePath).Length
        if ($currentSize -gt $thresholdBytes) {
            if (-not $DryRun -and $PSCmdlet.ShouldProcess($LogFilePath, 'Clear log file due to size')) {
                Clear-Content -Path $LogFilePath -Force
            }
            Write-LogMessage -Level 'WARNING' -Message 'Log file truncated due to size threshold' -Metadata @{
                FileName      = $LogFilePath
                CurrentSizeMB = [math]::Round($currentSize / 1MB, 2)
                ThresholdMB   = [math]::Round($thresholdBytes / 1MB, 2)
                DryRun        = $DryRun.IsPresent
            }
            return
        }

        Write-LogMessage -Level 'INFO' -Message 'No truncation needed; file under threshold' -Metadata @{
            FileName      = $LogFilePath
            CurrentSizeMB = [math]::Round($currentSize / 1MB, 2)
            ThresholdMB   = [math]::Round($thresholdBytes / 1MB, 2)
        }
        return
    }

    if ($TruncateLog) {
        if (-not $DryRun -and $PSCmdlet.ShouldProcess($LogFilePath, 'Clear entire log file')) {
            Clear-Content -Path $LogFilePath -Force
        }
        Write-LogMessage -Level 'WARNING' -Message 'Log file forcefully truncated' -Metadata @{
            FileName = $LogFilePath
            DryRun   = $DryRun.IsPresent
        }
        return
    }

    if (-not $applyTimestampFilter -and -not $hasMaxSizeMB) {
        Write-LogMessage -Level 'INFO' -Message 'No strategy applied. No valid parameters specified.' -Metadata @{ FileName = $LogFilePath }
    }
}
