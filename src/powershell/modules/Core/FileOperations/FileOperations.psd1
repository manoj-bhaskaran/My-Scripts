@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'FileOperations.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.1'

    # ID used to uniquely identify this module
    GUID = '8a9b0c1d-2e3f-4a5b-6c7d-8e9f0a1b2c3d'

    # Author of this module
    Author = 'My-Scripts'

    # Company or vendor of this module
    CompanyName = 'My-Scripts'

    # Copyright statement for this module
    Copyright = '(c) 2025 My-Scripts. Licensed under Apache License 2.0.'

    # Description of the functionality provided by this module
    Description = 'File operation utilities with built-in retry logic for PowerShell scripts.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Functions to export from this module
    FunctionsToExport = @(
        'Copy-FileWithRetry',
        'Move-FileWithRetry',
        'Remove-FileWithRetry',
        'Rename-FileWithRetry',
        'Test-FolderWritable',
        'Add-ContentWithRetry',
        'New-DirectoryIfNotExists',
        'Get-FileSize'
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
            Tags = @('FileOperations', 'Retry', 'IO', 'Utilities')
            LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri = 'https://github.com/manoj-bhaskaran/My-Scripts'
            ReleaseNotes = '1.0.1: Adopted Public/Private layout with module loader and dependency import cleanup.'
        }
    }
}
