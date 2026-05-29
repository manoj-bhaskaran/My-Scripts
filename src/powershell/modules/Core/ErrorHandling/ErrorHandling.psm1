# Module loader for ErrorHandling

$privateDir = Join-Path $PSScriptRoot 'Private'
if ([System.IO.Directory]::Exists($privateDir)) {
    Get-ChildItem -LiteralPath $privateDir -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
}

$publicDir = Join-Path $PSScriptRoot 'Public'
if ([System.IO.Directory]::Exists($publicDir)) {
    Get-ChildItem -LiteralPath $publicDir -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
}

$publicFunctions = if ([System.IO.Directory]::Exists($publicDir)) {
    Get-ChildItem -LiteralPath $publicDir -Filter '*.ps1' -File | Select-Object -ExpandProperty BaseName
}
else {
    @()
}

Export-ModuleMember -Function $publicFunctions
