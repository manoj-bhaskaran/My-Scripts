@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ErrorHandling.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.1'

    # ID used to uniquely identify this module
    GUID = '7f8e9a2b-3c4d-5e6f-7a8b-9c0d1e2f3a4b'

    # Author of this module
    Author = 'My-Scripts'

    # Company or vendor of this module
    CompanyName = 'My-Scripts'

    # Copyright statement for this module
    Copyright = '(c) 2025 My-Scripts. Licensed under Apache License 2.0.'

    # Description of the functionality provided by this module
    Description = 'Standardized error handling, retry logic, and privilege checking utilities for PowerShell scripts.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-WithErrorHandling',
        'Invoke-WithRetry',
        'Test-IsElevated',
        'Assert-Elevated',
        'Test-CommandAvailable'
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
            Tags = @('ErrorHandling', 'Retry', 'Elevation', 'Utilities')
            LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri = 'https://github.com/manoj-bhaskaran/My-Scripts'
            ReleaseNotes = '1.0.1: Standardized module layout with Public/Private folders and loader.'
        }
    }
}
