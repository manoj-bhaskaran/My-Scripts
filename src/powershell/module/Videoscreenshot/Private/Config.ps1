# Central config defaults (immutable template). Version is sourced from module manifest.
function Get-DefaultConfig {
  @{
    PollIntervalMs                  = 200
    SnapshotFallbackTimeoutSeconds  = 300
    SnapshotTerminationExtraSeconds = 5
    StopVlcWaitMs                   = 5000
    WaitProcessTimeoutSeconds       = 3
  }
}