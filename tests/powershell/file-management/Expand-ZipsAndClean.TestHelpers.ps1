Set-StrictMode -Version Latest

$script:ExpandZipsAndCleanRepositoryRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$script:ExpandZipsAndCleanModuleRoot = Join-Path $script:ExpandZipsAndCleanRepositoryRoot 'src/powershell/modules'

function Import-ExpandZipsAndCleanZipWorkflowTestModule {
    Import-Module (Join-Path $script:ExpandZipsAndCleanModuleRoot 'FileManagement/ZipWorkflow/ZipWorkflow.psm1') -Force -ErrorAction Stop
}

function Import-ExpandZipsAndCleanZipExtractionTestModule {
    Import-Module (Join-Path $script:ExpandZipsAndCleanModuleRoot 'FileManagement/ZipExtraction/ZipExtraction.psm1') -Force -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
}
