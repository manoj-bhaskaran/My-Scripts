<#
.SYNOPSIS
  Normalize a video file path for processed/resume tracking.
.DESCRIPTION
  Returns an absolute, provider path with consistent casing rules so that
  resume/skip lookups work reliably across runs and environments.
.PARAMETER Path
  Input path (relative or absolute).
.OUTPUTS
  [string] normalized absolute path.
#>
function Resolve-VideoPath {
    param([Parameter(Mandatory)][string]$Path)
    # Normalize for resume lookups: full path, invariant case for Windows
    $full = [IO.Path]::GetFullPath($Path)
    if ($IsWindows) { return $full.ToLowerInvariant() }
    return $full
}

function Convert-ProcessedLogLineToResumePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }

    $trimmedLine = $Line.Trim()
    if ($trimmedLine.StartsWith('#')) { return $null }

    $columns = $trimmedLine.Split("`t")
    $rawPath = $columns[0]
    $isTsv = $columns.Count -gt 1
    $status = if ($isTsv) { $columns[1] } else { 'Processed' }
    $reason = if ($columns.Count -ge 3) { $columns[2] } else { '' }
    $shouldSkip = Test-ProcessedLogEntryShouldSkip -Status $status -Reason $reason -LegacyEntry:(-not $isTsv)

    if (-not $shouldSkip -or [string]::IsNullOrWhiteSpace($rawPath)) { return $null }

    try {
        return (Resolve-VideoPath -Path $rawPath)
    }
    catch {
        return $rawPath
    }
}

function Test-ProcessedLogEntryShouldSkip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Status,
        [string]$Reason = '',
        [switch]$LegacyEntry
    )

    if ($LegacyEntry) { return $true }

    $normalizedStatus = $Status.Trim()
    $normalizedReason = ($Reason ?? '').Trim()

    if ($normalizedStatus.Equals('Processed', [StringComparison]::OrdinalIgnoreCase)) {
        return (-not $normalizedReason.Equals('NoFrames', [StringComparison]::OrdinalIgnoreCase))
    }

    if ($normalizedStatus.Equals('Skipped', [StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedReason.Equals('NotPlayable', [StringComparison]::OrdinalIgnoreCase)
    }

    return $false
}

<#
.SYNOPSIS
  Build a normalized set of already-processed video paths.
.DESCRIPTION
  Reads a processed log and returns a HashSet[string] of normalized absolute paths.
  Supports both the current TSV format (`<FullPath>`<tab>`<Status>`<tab>`<Reason>`<tab>`<Timestamp>`)
  and the **legacy format** that contains one `<FullPath>` per line. Blank lines and
  comment lines (starting with '#') are ignored.

  TSV rows are status-aware: only successful `Processed` rows, excluding
  `Processed`/`NoFrames`, and deliberate `Skipped`/`NotPlayable` rows are added to
  the resume skip set. Retry-eligible rows such as `Failed`, `TimedOutProcessed`,
  `Processed`/`NoFrames`, and `Skipped`/`VideoProbeError` are not skipped. Legacy
  single-column rows are treated as successful `Processed` entries for backward
  compatibility.
.PARAMETER Path
  Path to the processed log. The file may be missing (returns an empty set).
.OUTPUTS
  [System.Collections.Generic.HashSet[string]]
#>
function Get-ResumeIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )
    # Case-insensitive by default on Windows; keeps behavior stable cross-platform.
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Output -NoEnumerate $set
        return
    }
    try {
        Get-Content -LiteralPath $Path -ErrorAction Stop | ForEach-Object {
            $full = Convert-ProcessedLogLineToResumePath -Line $_
            if (-not [string]::IsNullOrWhiteSpace($full)) {
                [void]$set.Add($full)
            }
        }
    }
    catch {
        Write-Debug ("Get-ResumeIndex: failed to read '{0}': {1}" -f $Path, $_.Exception.Message)
    }
    Write-Output -NoEnumerate $set
}

<#
.SYNOPSIS
  Append a processed/skip record to the processed log.
.DESCRIPTION
  Writes a TSV line in the form `<FullPath>\t<Status>\t<Reason>\t<Timestamp>`.
  The path is written in the first column for compatibility with Get-ResumeIndex.
  The reader accepts both TSV (this) and legacy single-column logs; new writes use TSV.
.PARAMETER Path
  Processed log path to append to (created if missing).
.PARAMETER VideoPath
  The video file path to record (will be normalized).
.PARAMETER Status
  Status string (e.g., 'Processed', 'Skipped').
.PARAMETER Reason
  Optional reason string (e.g., 'NotPlayable').
#>
function Write-ProcessedLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$VideoPath,
        [Parameter(Mandatory)][ValidateSet('Processed', 'TimedOutProcessed', 'Skipped', 'Failed')][string]$Status,
        [string]$Reason = ''
    )
    # TSV format: <FullPath>\t<Status>\t<Reason>\t<Timestamp>
    # Path must be first column for Get-ResumeIndex to work correctly
    $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffK')
    $line = "{0}`t{1}`t{2}`t{3}" -f (Resolve-VideoPath -Path $VideoPath), $Status, ($Reason ?? ''), $ts
    # Using-style write with retry (exclusive append)
    for ($i = 1; $i -le 3; $i++) {
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes($line + [Environment]::NewLine)
            $fs = [IO.File]::Open($Path, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try {
                $fs.Write($bytes, 0, $bytes.Length)
            }
            finally {
                $fs.Dispose()
            }
            return
        }
        catch {
            if ($i -eq 3) { throw "Failed to append to processed log '$Path' — $($_.Exception.Message)" }
            Start-Sleep -Milliseconds (150 * $i)
        }
    }
}
