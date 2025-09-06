<# 
  Requires: PowerShell 5.1+ (or PowerShell 7+)
  videoscreenshot.ps1 (shim)
  This thin wrapper preserves the existing CLI entrypoint while the implementation lives
  in the Videoscreenshot PowerShell module. For full functionality, import the module
  and call Start-VideoBatch directly.
#>

[CmdletBinding()]
param(
  [string]$SourceFolder = (Join-Path $PSScriptRoot 'videos'),
  [string]$SaveFolder   = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Screenshots'),
  [ValidateRange(1,60)][int]$FramesPerSecond = 1,
  [int]$TimeLimitSeconds = 0,
  [int]$VideoLimit = 0,
  [switch]$CropOnly,
  [string]$ResumeFile,
  [string]$PythonScriptPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'python\crop_colours.py'),
  [string]$PythonExe,
  [string]$ProcessedLogPath,
  [switch]$UseVlcSnapshots,
  [int]$VlcStartupTimeoutSeconds = 10,
  [switch]$GdiFullscreen,
  [switch]$Legacy1080p,
  [switch]$ClearSnapshotsBeforeRun,
  [int]$AutoStopGraceSeconds = 2,
  [switch]$DisableAutoStop
)

$modulePs1 = Join-Path $PSScriptRoot 'module\Videoscreenshot\Videoscreenshot.psd1'
if (-not (Test-Path -LiteralPath $modulePs1)) {
  Write-Error "Videoscreenshot module not found at: $modulePs1"
  exit 1
}

Import-Module $modulePs1 -Force -ErrorAction Stop
Write-Warning "videoscreenshot.ps1 is now a thin wrapper. Prefer: Import-Module …\Videoscreenshot; Start-VideoBatch …"

# Forward only parameters that Start-VideoBatch actually supports
$cmd = Get-Command -Name Start-VideoBatch -ErrorAction Stop
$supported = $cmd.Parameters.Keys

$forward = @{}
foreach ($name in @('SourceFolder','SaveFolder','FramesPerSecond','TimeLimitSeconds','VideoLimit','VlcStartupTimeoutSeconds')) {
  if ($supported -contains $name) {
    $forward[$name] = Get-Variable -Name $name -ValueOnly
  }
}
# Switch params: include only if the caller supplied them
foreach ($sw in @('UseVlcSnapshots','GdiFullscreen')) {
  if ($supported -contains $sw -and $PSBoundParameters.ContainsKey($sw)) {
    $forward[$sw] = $true
  }
}

# Warn about legacy/ignored params if the caller provided them
$legacyOnly = @(
  'CropOnly','ResumeFile','PythonScriptPath','PythonExe','ProcessedLogPath',
  'Legacy1080p','ClearSnapshotsBeforeRun','AutoStopGraceSeconds','DisableAutoStop'
)
$ignored = $legacyOnly | Where-Object { $PSBoundParameters.ContainsKey($_) -and -not ($supported -contains $_) }
if ($ignored) {
  Write-Warning ("The following parameters are not used by the module's Start-VideoBatch in v1.3.0 and were ignored: {0}" -f ($ignored -join ', '))
}

Start-VideoBatch @forward