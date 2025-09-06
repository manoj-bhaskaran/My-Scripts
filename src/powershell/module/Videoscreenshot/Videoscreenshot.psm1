# Dot-source private and public functions (deterministic order, resilient if a folder is absent)
$here       = Split-Path -Parent $PSCommandPath
$privateDir = Join-Path -Path $here -ChildPath 'Private'
$publicDir  = Join-Path -Path $here -ChildPath 'Public'

if (Test-Path -LiteralPath $privateDir) {
    Get-ChildItem -LiteralPath $privateDir -Filter *.ps1 -File -ErrorAction Stop |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

if (Test-Path -LiteralPath $publicDir) {
    Get-ChildItem -LiteralPath $publicDir -Filter *.ps1 -File -ErrorAction Stop |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

# Export public API
Export-ModuleMember -Function Start-VideoBatch
