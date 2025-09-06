function Write-Message {
  [CmdletBinding()]
  param(
    [ValidateSet('Info','Warn','Error')][string]$Level = 'Info',
    [Parameter(Mandatory)][string]$Message
  )
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $formatted = "[$ts] [$($Level.ToUpper().PadRight(5))] $Message"
  switch ($Level) {
    'Info'  { try { Write-Information -MessageData $formatted -InformationAction Continue } catch { Write-Host $formatted -ForegroundColor Cyan } }
    'Warn'  { Write-Warning $formatted; Write-Debug $formatted }
    'Error' { Write-Error   $formatted; Write-Debug $formatted }
  }
}
