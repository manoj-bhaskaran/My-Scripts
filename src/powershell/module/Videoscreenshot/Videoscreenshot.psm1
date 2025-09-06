# Dot-source private and public functions
$here = Split-Path -Parent $PSCommandPath
Get-ChildItem -Path (Join-Path $here 'Private') -Filter *.ps1 | ForEach-Object { . $_.FullName }
Get-ChildItem -Path (Join-Path $here 'Public')  -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Export public API
Export-ModuleMember -Function Start-VideoBatch
