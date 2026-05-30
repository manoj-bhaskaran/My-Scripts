# Module loader for ProgressReporter

$fileSystemModule = Join-Path $PSScriptRoot '..\FileSystem\FileSystem.psm1'
if (-not (Test-Path -LiteralPath $fileSystemModule)) {
    throw "Required module dependency not found: $fileSystemModule"
}
Import-Module $fileSystemModule -Force -ErrorAction Stop

$privateDir = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $privateDir) {
    Get-ChildItem -Path $privateDir -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
}

$publicDir = Join-Path $PSScriptRoot 'Public'
if (Test-Path -LiteralPath $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
}

$publicFunctions = if (Test-Path -LiteralPath $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | Select-Object -ExpandProperty BaseName
}
else {
    @()
}

Export-ModuleMember -Function $publicFunctions
