# FileDistributor.psm1 - File Distributor Support Module

$ModuleRoot = $PSScriptRoot

# Import shared Core dependencies used by private/public FileDistributor functions
Import-Module (Join-Path -Path $ModuleRoot -ChildPath '..\..\Core\ErrorHandling\ErrorHandling.psd1') -Force
Import-Module (Join-Path -Path $ModuleRoot -ChildPath '..\..\Core\FileOperations\FileOperations.psd1') -Force

$privateFunctions = @(Get-ChildItem -Path "$ModuleRoot\Private\*.ps1" -ErrorAction SilentlyContinue)
foreach ($import in $privateFunctions) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import private function $($import.FullName): $_"
    }
}

$publicFunctions = @(Get-ChildItem -Path "$ModuleRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
foreach ($import in $publicFunctions) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import public function $($import.FullName): $_"
    }
}

Export-ModuleMember -Function $publicFunctions.BaseName
