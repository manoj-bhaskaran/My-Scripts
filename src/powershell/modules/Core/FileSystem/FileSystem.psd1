@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'FileSystem.psm1'

    # Version number of this module.
    ModuleVersion     = '1.1.0'

    # ID used to uniquely identify this module
    GUID              = '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d'

    # Author of this module
    Author            = 'My-Scripts'

    # Company or vendor of this module
    CompanyName       = 'My-Scripts'

    # Copyright statement for this module
    Copyright         = '(c) 2025 My-Scripts. Licensed under Apache License 2.0.'

    # Description of the functionality provided by this module
    Description       = 'Common file system operations including directory creation, file accessibility checks, path validation, file locking detection, path normalization, safe naming, and byte formatting.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @()

    # Functions to export from this module
    FunctionsToExport = @(
        'New-DirectoryIfMissing',
        'Test-FileAccessible',
        'Test-PathValid',
        'Test-FileLocked',
        'Get-FullPath',
        'Format-Bytes',
        'Resolve-UniquePath',
        'Resolve-UniqueDirectoryPath',
        'Get-SafeName',
        'Test-LongPathsEnabled'
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
            Tags         = @('FileSystem', 'IO', 'Utilities', 'PathValidation', 'FileLocking', 'PathNormalization', 'SafeNaming')
            LicenseUri   = 'http://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri   = 'https://github.com/manoj-bhaskaran/My-Scripts'
            ReleaseNotes = '1.1.0: Added path normalization (Get-FullPath), byte formatting (Format-Bytes), unique path resolution (Resolve-UniquePath, Resolve-UniqueDirectoryPath), safe filenames (Get-SafeName), and long paths OS check (Test-LongPathsEnabled).
1.0.0: Initial release with directory creation, file accessibility checks, path validation, and file locking detection.'
        }
    }
}
