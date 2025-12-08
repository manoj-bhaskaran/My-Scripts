@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'FileQueue.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'f8a3c5d1-9e2b-4a7c-8d6f-1e3a5b7c9d2e'

    # Author of this module
    Author = 'Manoj Bhaskaran'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'File queue management module for file distribution operations. Provides queue initialization, item management, and state persistence for file operations.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'New-FileQueue',
        'Add-FileToQueue',
        'Get-NextQueueItem',
        'Remove-QueueItem',
        'Save-QueueState',
        'Restore-QueueState'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('FileManagement', 'Queue', 'Distribution')
            ProjectUri = 'https://github.com/manoj-bhaskaran/My-Scripts'
        }
    }
}
