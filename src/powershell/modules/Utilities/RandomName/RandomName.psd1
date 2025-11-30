@{
    # Module manifest for RandomName
    RootModule        = 'RandomName.psm1'
    ModuleVersion     = '2.1.1'
    GUID              = '6b2a2d3e-0e1f-4a4b-9f5b-9c7a2f9d2c4a'
    Author            = 'Manoj Bhaskaran'
    CompanyName       = ''
    Description       = 'Generates Windows-safe random file names using a conservative allow-list.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-RandomFileName')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('random','filename','windows-safe')
            ProjectUri   = ''
            ReleaseNotes = '2.1.1: Standardized module loader with Public/Private directories.'
        }
    }
}
