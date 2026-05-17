#requires -Version 7.0
using namespace System.IO.Compression

# Load the ZIP assembly before dot-sourcing functions that reference ZipFile types.
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# Provide a no-op Write-LogDebug when the logging framework is not loaded so the module
# works standalone in tests and other contexts where logging is not initialised.
if (-not (Get-Command -Name Write-LogDebug -ErrorAction SilentlyContinue)) {
    function Write-LogDebug { param([string]$Message) }
}

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
