<#
.SYNOPSIS
Legacy wrapper removed.

.DESCRIPTION
The legacy script `videoscreenshot.ps1` has been decommissioned. Use the Videoscreenshot
module and call `Start-VideoBatch` directly.

Examples:
  Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
  Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 [-UseVlcSnapshots]

For help:
  Get-Help Start-VideoBatch -Full
#>

[CmdletBinding()]
param()

$msg = @"
'videoscreenshot.ps1' has been removed.
Use the Videoscreenshot module entrypoint instead:

  Import-Module \src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
  Start-VideoBatch -SourceFolder <videos> -SaveFolder <shots> -FramesPerSecond 2 [-UseVlcSnapshots]

For detailed help: Get-Help Start-VideoBatch -Full
"@

Write-Error $msg
exit 2