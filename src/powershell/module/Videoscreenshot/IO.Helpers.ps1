function Add-ContentWithRetry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Value,
    [ValidateRange(1,10)][int]$MaxAttempts = 3
  )
  for ($i=1; $i -le $MaxAttempts; $i++) {
    try {
      $nl = [Environment]::NewLine
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value + $nl)
      $fs = [System.IO.File]::Open($Path,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try {
        $fs.Write($bytes,0,$bytes.Length)
      } finally {
        # Ensure the handle is always released even if Write() throws.
        if ($null -ne $fs) { $fs.Dispose() }
      }
      return $true
    } catch {
      if ($i -eq $MaxAttempts) {
        Write-Message -Level Error -Message ('Failed to append to {0}: {1}' -f $Path, $_.Exception.Message)
        return $false
      }
      Start-Sleep -Milliseconds (200 * $i)
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
