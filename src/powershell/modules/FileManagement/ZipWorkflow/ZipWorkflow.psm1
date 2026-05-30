#requires -Version 7.0

$coreModules = @(
    '..\..\Core\FileSystem\FileSystem.psm1',
    '..\..\Core\Progress\ProgressReporter.psm1',
    '..\..\Core\FileOperations\FileOperations.psm1'
)
$modulePathComparer = if ($IsWindows) {
    [System.StringComparer]::OrdinalIgnoreCase
} else {
    [System.StringComparer]::Ordinal
}

foreach ($relativeModulePath in $coreModules) {
    $modulePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $relativeModulePath))
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension(($relativeModulePath -split '[\\/]' | Select-Object -Last 1))

    if (-not (Test-Path -LiteralPath $modulePath)) {
        throw "Required module dependency not found: $modulePath"
    }

    $loadedModule = Get-Module -Name $moduleName | Where-Object {
        $_.Path -and $modulePathComparer.Equals(
            [System.IO.Path]::GetFullPath($_.Path),
            $modulePath
        )
    } | Select-Object -First 1

    if ($loadedModule) {
        continue
    }

    Import-Module $modulePath -Force -ErrorAction Stop
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
