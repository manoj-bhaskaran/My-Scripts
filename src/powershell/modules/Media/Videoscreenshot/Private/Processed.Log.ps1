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

<#
.SYNOPSIS
  Build a normalized set of already-processed video paths.
.DESCRIPTION
  Reads a processed log and returns a HashSet[string] of normalized absolute paths.
  Supports both the current TSV format (`<FullPath>`<tab>`<Status>`) and the
  **legacy format** that contains one `<FullPath>` per line. Blank lines and
  comment lines (starting with '#') are ignored. Status values in TSV are
  currently informational; presence of the path implies “already processed”.
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
    if (-not (Test-Path -LiteralPath $Path)) { return $set }
    try {
        Get-Content -LiteralPath $Path -ErrorAction Stop | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) { return }
            $line = $_.Trim()
            if ($line.StartsWith('#')) { return }

            $rawPath = $null
            if ($line -like "*`t*") {
                # TSV (current) format: <FullPath>\t<Status>[\t<Reason>]
                $rawPath = ($line.Split("`t"))[0]
            }
            else {
                # Legacy format: a single path per line
                $rawPath = $line
            }

            if (-not [string]::IsNullOrWhiteSpace($rawPath)) {
                try {
                    $full = Resolve-VideoPath -Path $rawPath
                }
                catch {
                    $full = $rawPath
                }
                if (-not [string]::IsNullOrWhiteSpace($full)) {
                    [void]$set.Add($full)
                }
            }
        }
    }
    catch {
        Write-Debug ("Get-ResumeIndex: failed to read '{0}': {1}" -f $Path, $_.Exception.Message)
    }
    return $set
}

<#
.SYNOPSIS
  Append a processed/skip record to the processed log.
.DESCRIPTION
  Writes a TSV line in the form `<FullPath>\t<Status>\t<Reason?>`. The current
  skipper accepts both TSV (this) and legacy single-column logs; new writes use TSV.
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
    $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffK')
    $line = "{0}`t{1}`t{2}`t{3}" -f $ts, $Status, ($Reason ?? ''), (Resolve-VideoPath -Path $VideoPath)
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