# Simple per-run PID file with safe writes (state carried via $Context)
function Initialize-PidRegistry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [Parameter(Mandatory)][string]$SaveFolder,
    [Parameter(Mandatory)][string]$RunGuid
  )
  $path = Join-Path $SaveFolder ".vlc_pids_$RunGuid.txt"
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  }
  $Context.PidRegistryPath = $path
  $path
}
function Register-RunPid {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [Parameter(Mandatory)][int]$ProcessId
  )
  if (-not $Context.PidRegistryPath) { throw "PID registry not initialized." }
  $null = Add-ContentWithRetry -Path $Context.PidRegistryPath -Value $ProcessId
}
function Unregister-RunPid {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [Parameter(Mandatory)][int]$ProcessId
  )
  if ($Context.PidRegistryPath -and (Test-Path -LiteralPath $Context.PidRegistryPath)) {
    (Get-Content -LiteralPath $Context.PidRegistryPath | Where-Object { $_ -ne "$ProcessId" }) |
      Set-Content -LiteralPath $Context.PidRegistryPath -Encoding utf8 | Out-Null
  }
}
