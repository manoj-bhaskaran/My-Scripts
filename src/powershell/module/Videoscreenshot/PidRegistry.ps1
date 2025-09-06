# Simple per-run PID file with safe writes
$script:PidRegistryPath = $null
function Initialize-PidRegistry {
  param([Parameter(Mandatory)][string]$SaveFolder,[string]$RunGuid)
  $script:PidRegistryPath = Join-Path $SaveFolder ".vlc_pids_$RunGuid.txt"
  if (Test-Path -LiteralPath $PidRegistryPath) { Remove-Item -LiteralPath $PidRegistryPath -Force -ErrorAction SilentlyContinue }
  $script:PidRegistryPath
}
function Register-RunPid { param([Parameter(Mandatory)][int]$ProcessId) $null = Add-ContentWithRetry -Path $script:PidRegistryPath -Value $ProcessId }
function Unregister-RunPid {
  param([Parameter(Mandatory)][int]$ProcessId)
  if (Test-Path -LiteralPath $script:PidRegistryPath) {
    (Get-Content -LiteralPath $script:PidRegistryPath | Where-Object { $_ -ne "$ProcessId" }) |
      Set-Content -LiteralPath $script:PidRegistryPath -Encoding utf8 | Out-Null
  }
}
