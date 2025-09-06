# Central config & version (semver patch for fixes in this PR)
$script:VideoScreenshotVersion = '1.3.2'
$script:Config = @{
  PollIntervalMs                    = 200
  SnapshotFallbackTimeoutSeconds    = 300
  SnapshotTerminationExtraSeconds   = 5
  StopVlcWaitMs                     = 5000
  WaitProcessTimeoutSeconds         = 3
}

# Run stats context (will be threaded instead of globals in follow-up PR)
$script:RunStats = [pscustomobject]@{
  StartTime         = Get-Date
  TotalFiles        = 0
  Attempted         = 0
  Processed         = 0
  TimedOutProcessed = 0
  SkippedAlready    = 0
  Failures          = 0
  FramesSaved       = 0
}

# Script-wide exit code placeholder (computed at the end in future PRs)
$script:ExitCode = 0

# Requested FPS placeholder used by Start-Vlc (set by Start-VideoBatch)
