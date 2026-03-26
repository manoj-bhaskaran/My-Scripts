@{
    # Module manifest for PurgeLogs
    RootModule        = 'PurgeLogs.psm1'
    ModuleVersion     = '2.1.1'
    GUID              = '8e9f2b4d-6c3a-4f7e-9d5b-2a8c4e6f1b3d'
    Author            = 'Manoj Bhaskaran'
    CompanyName       = ''
    Description       = 'Log file purging and retention management with support for multiple strategies (retention days, max size, truncation)'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Clear-LogFile', 'ConvertTo-Bytes')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('logging','purge','retention','cleanup','maintenance')
            ProjectUri   = ''
            ReleaseNotes = '2.1.1: Align RootModule ConvertTo-Bytes with K/M/G and KB/MB/GB suffix parsing; tests now import manifest path.'
        }
    }
}
