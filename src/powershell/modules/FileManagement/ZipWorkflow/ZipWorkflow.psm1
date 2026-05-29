#requires -Version 7.0

$coreModules = @(
    '..\..\Core\FileSystem\FileSystem.psm1',
    '..\..\Core\Progress\ProgressReporter.psm1',
    '..\..\Core\FileOperations\FileOperations.psm1'
)
foreach ($relativeModulePath in $coreModules) {
    $modulePath = Join-Path $PSScriptRoot $relativeModulePath
    if (Test-Path -LiteralPath $modulePath) {
        Import-Module $modulePath -Force
    }
}

# Provide no-op logging fallback for helper-load/test contexts where the
# logging framework is not imported into the same scope as this module.
if (-not (Get-Command -Name Write-LogDebug -ErrorAction SilentlyContinue)) {
    function Write-LogDebug { param([string]$Message) }
}

$publicDir = Join-Path $PSScriptRoot 'Public'
if (Test-Path -LiteralPath $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
}
$publicFunctions = if (Test-Path -LiteralPath $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | Select-Object -ExpandProperty BaseName
} else { @() }
Export-ModuleMember -Function $publicFunctions
