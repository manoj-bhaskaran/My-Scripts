function Add-ContentWithRetry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Value,
    [ValidateRange(1,10)][int]$MaxAttempts = 3
  )
  # Contract: succeeds or throws. No partial returns.
  for ($i = 1; $i -le $MaxAttempts; $i++) {
    $fs = $null
    try {
      $nl    = [Environment]::NewLine
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value + $nl)
      $fs = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Append,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
      )
      $fs.Write($bytes, 0, $bytes.Length)
      return $true
    } catch {
      if ($i -ge $MaxAttempts) {
        throw ("Failed to append to '{0}' after {1} attempts: {2}" -f $Path, $MaxAttempts, $_.Exception.Message)
      }
      Start-Sleep -Milliseconds (200 * $i)
    } finally {
      if ($null -ne $fs) {
        try { $fs.Dispose() } catch { }
      }
    }
  }
}
function Test-FolderWritable {
  [CmdletBinding()]
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Folder)
  try {
    if (-not (Test-Path -LiteralPath $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }
    $tmp = Join-Path $Folder (".writetest_{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
    [IO.File]::WriteAllText($tmp,'ok'); Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    return $true
  } catch { throw "Folder is not writable: $Folder – $($_.Exception.Message)" }
}
