@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ProgressReporter.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = '9b0c1d2e-3f4a-5b6c-7d8e-9f0a1b2c3d4e'

    # Author of this module
    Author = 'My-Scripts'

    # Company or vendor of this module
    CompanyName = 'My-Scripts'

    # Copyright statement for this module
    Copyright = '(c) 2025 My-Scripts. Licensed under Apache License 2.0.'

    # Description of the functionality provided by this module
    Description = 'Standardized progress reporting utilities for PowerShell scripts with logging integration.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Show-Progress',
        'Write-ProgressLog',
        'New-ProgressTracker',
        'Update-ProgressTracker',
        'Complete-ProgressTracker',
        'Write-ProgressStatus'
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
            Tags = @('Progress', 'Logging', 'Reporting', 'Utilities')
            LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri = 'https://github.com/manoj-bhaskaran/My-Scripts'
            ReleaseNotes = 'Initial release of ProgressReporter module with standardized progress tracking and logging integration.'
        }
    }
}
