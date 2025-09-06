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
# Build wrapper → module parameter forwarding with parity checks
$sbParams = (Get-Command Start-VideoBatch -ErrorAction Stop).Parameters.Keys
$renameMap = @{
  # legacy → module
  'CropOnly' = 'RunCropper'
}

$forward     = @{}
$translated  = New-Object System.Collections.Generic.List[string]
$ignored     = New-Object System.Collections.Generic.List[string]

# Include wrapper defaults for core params to keep parity with historical behavior
$coreDefaults = @{
  SourceFolder              = $SourceFolder
  SaveFolder                = $SaveFolder
  FramesPerSecond           = $FramesPerSecond
  TimeLimitSeconds          = $TimeLimitSeconds
  VideoLimit                = $VideoLimit
  UseVlcSnapshots           = [bool]$UseVlcSnapshots
  GdiFullscreen             = [bool]$GdiFullscreen
  VlcStartupTimeoutSeconds  = $VlcStartupTimeoutSeconds
  PythonScriptPath          = $PythonScriptPath
  PythonExe                 = $PythonExe
  ClearSnapshotsBeforeRun   = [bool]$ClearSnapshotsBeforeRun
}
foreach ($k in $coreDefaults.Keys) {
  if ($sbParams -contains $k) { $forward[$k] = $coreDefaults[$k] }
}

# Apply user-specified parameters, handling renames and collecting unsupported
foreach ($k in $PSBoundParameters.Keys) {
  if ($renameMap.ContainsKey($k)) {
    $new = $renameMap[$k]
    if ($sbParams -contains $new) {
      $forward[$new] = $PSBoundParameters[$k]
      $null = $translated.Add("$k->$new")
    } else {
      $null = $ignored.Add($k)
    }
  } elseif ($sbParams -contains $k) {
    $forward[$k] = $PSBoundParameters[$k]
  } else {
    $null = $ignored.Add($k)
  }
}

# Emit a single, clear warning about deprecation + parameter handling
$parts = @("videoscreenshot.ps1 is a thin wrapper; prefer: Import-Module …\Videoscreenshot; Start-VideoBatch …")
if ($translated.Count -gt 0) { $parts += "Translated legacy parameter(s): $($translated -join ', ')" }
if ($ignored.Count -gt 0)    { $parts += "Ignored unsupported parameter(s): $($ignored -join ', ')" }
Write-Warning ($parts -join ' | ')

# Invoke module entrypoint with curated parameter set
Start-VideoBatch @forward