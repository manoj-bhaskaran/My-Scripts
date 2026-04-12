# FileDistributor.psm1 - File Distributor Support Module

$ModuleRoot = $PSScriptRoot

$runStateClassPath = Join-Path -Path $ModuleRoot -ChildPath 'Private\FileDistributorRunState.ps1'
if (Test-Path -LiteralPath $runStateClassPath) {
    . $runStateClassPath
}

$privateFunctions = @(Get-ChildItem -Path "$ModuleRoot\Private\*.ps1" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'FileDistributorRunState.ps1' } | Sort-Object Name)
foreach ($import in $privateFunctions) {
    try {
        . $import.FullName
    } catch {
        Write-Error "Failed to import private function $($import.FullName): $_"
    }
}

$publicFunctions = @(Get-ChildItem -Path "$ModuleRoot\Public\*.ps1" -ErrorAction SilentlyContinue | Sort-Object Name)
foreach ($import in $publicFunctions) {
    try {
        . $import.FullName
    } catch {
        Write-Error "Failed to import public function $($import.FullName): $_"
    }
}

Export-ModuleMember -Function $publicFunctions.BaseName
