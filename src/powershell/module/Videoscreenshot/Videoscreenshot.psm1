# Dot-source private and public functions (robust to missing folders; also load flat layout)
$here    = Split-Path -Parent $PSCommandPath
$private = Join-Path $here 'Private'
$public  = Join-Path $here 'Public'

if (Test-Path -LiteralPath $private) {
  Get-ChildItem -Path $private -Filter *.ps1 -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { . $_.FullName }
}
if (Test-Path -LiteralPath $public) {
  Get-ChildItem -Path $public -Filter *.ps1 -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { . $_.FullName }
}
# Also dot-source any top-level *.ps1 (for repos that keep a flat layout)
Get-ChildItem -Path $here -Filter *.ps1 -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notin @('Videoscreenshot.psm1','Videoscreenshot.psd1') } |
  Sort-Object Name |
  ForEach-Object { . $_.FullName }

# Export public API
Export-ModuleMember -Function Start-VideoBatch
