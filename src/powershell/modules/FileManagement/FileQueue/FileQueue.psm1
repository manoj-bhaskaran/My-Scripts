# FileQueue.psm1 - File Queue Management Module

# Get module root path
$ModuleRoot = $PSScriptRoot

# Import private functions
$privateFunctions = @(Get-ChildItem -Path "$ModuleRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

foreach ($import in $privateFunctions) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import private function $($import.FullName): $_"
    }
}

# Import public functions
$publicFunctions = @(Get-ChildItem -Path "$ModuleRoot\Public\*.ps1" -ErrorAction SilentlyContinue)

foreach ($import in $publicFunctions) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import public function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $publicFunctions.BaseName
