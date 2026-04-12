@{
    RootModule        = 'FileDistributor.psm1'
    ModuleVersion     = '1.3.0'
    GUID              = '7ce4ef6c-cc9f-4c89-a0d9-6c2751f4f0df'
    Author            = 'Manoj Bhaskaran'
    CompanyName       = 'Unknown'
    Copyright         = '(c) 2026. All rights reserved.'
    Description       = 'Support module for FileDistributor.ps1 — path helpers, retry helpers, state management, and core distribution algorithms.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Initialize-FileDistributorPaths',
        'Invoke-ParameterValidation',
        'Invoke-RestoreCheckpoint',
        'New-CheckpointPayload',
        'Invoke-DistributionPhase',
        'Invoke-PostProcessingPhase',
        'Invoke-EndOfScriptDeletion',
        'Invoke-PostRunCleanup',
        'Invoke-DistributionLockRelease',
        'Invoke-FileDistribution',
        'Invoke-TargetRedistribution',
        'Invoke-FolderRebalance',
        'Invoke-DistributionRandomize',
        'Invoke-FolderConsolidation'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('FileManagement', 'FileDistributor', 'Private')
            ProjectUri = 'https://github.com/manoj-bhaskaran/My-Scripts'
        }
    }
}
