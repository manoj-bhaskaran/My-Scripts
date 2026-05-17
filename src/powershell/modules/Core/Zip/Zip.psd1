@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'Zip.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = 'a1b2c3d4-e5f6-7a8b-9c0d-e1f2a3b4c5d6'

    # Author of this module
    Author            = 'Manoj Bhaskaran'

    # Company or vendor of this module
    CompanyName       = 'My-Scripts'

    # Copyright statement for this module
    Copyright         = '(c) 2025 My-Scripts. Licensed under Apache License 2.0.'

    # Description of the functionality provided by this module
    Description       = 'ZIP archive primitives: stats collection, per-archive subfolder extraction, flat streaming extraction with collision handling, and Zip Slip path-traversal protection.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @()

    # Functions to export from this module
    FunctionsToExport = @(
        'Get-ZipFileStats',
        'Expand-ZipToSubfolder',
        'Expand-ZipFlat',
        'Expand-ZipSmart'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            Tags         = @('Zip', 'Archive', 'Compression', 'Extraction', 'ZipSlip', 'FileManagement')
            LicenseUri   = 'http://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri   = 'https://github.com/manoj-bhaskaran/My-Scripts'
            ReleaseNotes = '1.0.0: Initial release. Archive primitives extracted from Expand-ZipsAndClean.ps1 (issue #976). Public: Get-ZipFileStats, Expand-ZipToSubfolder, Expand-ZipFlat, Expand-ZipSmart. Private: Test-IsEncryptedZipError, Resolve-ExtractionError, Resolve-ZipEntryDestinationPath.'
        }
    }
}
