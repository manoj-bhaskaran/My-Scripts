function New-VideoRunContext {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateRange(1,1000)][int]$RequestedFps,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RunGuid
  )
  $mod = Get-Module -Name 'Videoscreenshot'
  $version = if ($mod) { $mod.Version.ToString() } else { '1.3.4' }
  $cfg = Get-DefaultConfig
  # stats object is per-run and intentionally mutable but isolated inside the context
  $stats = [pscustomobject]@{
    StartTime         = Get-Date
    TotalFiles        = 0
    Attempted         = 0
    Processed         = 0
    TimedOutProcessed = 0
    SkippedAlready    = 0
    Failures          = 0
    FramesSaved       = 0
  }
  [pscustomobject]@{
    Version         = $version
    Config          = $cfg
    Stats           = $stats
    ExitCode        = 0
    RequestedFps    = $RequestedFps
    SaveFolder      = $SaveFolder
    RunGuid         = $RunGuid
    PidRegistryPath = $null
  }
}