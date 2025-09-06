<# 
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

Import-Module $modulePs1 -Force
Write-Warning "videoscreenshot.ps1 is now a thin wrapper. Prefer: Import-Module …\Videoscreenshot; Start-VideoBatch …"

# Pass only parameters supported by Start-VideoBatch (avoid splatting unknown keys)
Start-VideoBatch `
  -SourceFolder $SourceFolder `
  -SaveFolder $SaveFolder `
  -FramesPerSecond $FramesPerSecond `
  -TimeLimitSeconds $TimeLimitSeconds `
  -VideoLimit $VideoLimit `
  -UseVlcSnapshots:$UseVlcSnapshots `
  -GdiFullscreen:$GdiFullscreen `
  -VlcStartupTimeoutSeconds $VlcStartupTimeoutSeconds