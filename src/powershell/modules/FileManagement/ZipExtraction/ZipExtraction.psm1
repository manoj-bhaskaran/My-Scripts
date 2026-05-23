#requires -Version 7.0
using namespace System.Collections.Concurrent

# Provide no-op logging fallbacks for helper-load contexts where the logging framework
# is not imported into the same scope as this module.
if (-not (Get-Command -Name Write-LogInfo -ErrorAction SilentlyContinue)) {
    function Write-LogInfo { param([string]$Message) }
}
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
} else { @() }

Export-ModuleMember -Function $publicFunctions
