# GDI+ capture (private helper)
# NOTE: This is a placeholder implementation. It enforces the "helpers throw" policy
# and provides a clear message if the path is hit before the feature is implemented.
# When implemented, return a typed object:
#   [pscustomobject]@{ FramesSaved = [int]<count>; AchievedFps = [double]<fps> }
function Invoke-GdiCapture {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateRange(1,86400)][int]$DurationSeconds,
    [Parameter(Mandatory)][ValidateRange(1,60)][int]$Fps,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix
  )

  throw "Invoke-GdiCapture is not implemented yet. Use -UseVlcSnapshots or add a GDI capture implementation in Private/Gdi.Capture.ps1."
}