function Resolve-VideoPath {
  param([Parameter(Mandatory)][string]$Path)
  # Normalize for resume lookups: full path, invariant case for Windows
  $full = [IO.Path]::GetFullPath($Path)
  if ($IsWindows) { return $full.ToLowerInvariant() }
  return $full
}

function Get-ResumeIndex {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path
  )
  $set = [System.Collections.Generic.HashSet[string]]::new()
  if (-not (Test-Path -LiteralPath $Path)) { return $set }
  try {
    Get-Content -LiteralPath $Path -ErrorAction Stop | ForEach-Object {
      # TSV: Timestamp\tStatus\tReason\tVideoPath
      if ([string]::IsNullOrWhiteSpace($_)) { return }
      $parts = $_ -split "`t", 4
      if ($parts.Length -eq 4) {
        $null = $set.Add((Resolve-VideoPath -Path $parts[3]))
      }
    }
  } catch {
    throw "Failed to read resume/processed log '$Path' — $($_.Exception.Message)"
  }
  return $set
}

function Write-ProcessedLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$VideoPath,
    [Parameter(Mandatory)][ValidateSet('Processed','TimedOutProcessed','Skipped','Failed')][string]$Status,
    [string]$Reason = ''
  )
  $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffK')
  $line = "{0}`t{1}`t{2}`t{3}" -f $ts, $Status, ($Reason ?? ''), (Resolve-VideoPath -Path $VideoPath)
  # Using-style write with retry (exclusive append)
  for ($i=1; $i -le 3; $i++) {
    try {
      $bytes = [Text.Encoding]::UTF8.GetBytes($line + [Environment]::NewLine)
      $fs = [IO.File]::Open($Path, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::None)
      try {
        $fs.Write($bytes, 0, $bytes.Length)
      } finally {
        $fs.Dispose()
      }
      return
    } catch {
      if ($i -eq 3) { throw "Failed to append to processed log '$Path' — $($_.Exception.Message)" }
      Start-Sleep -Milliseconds (150 * $i)
    }
  }
}