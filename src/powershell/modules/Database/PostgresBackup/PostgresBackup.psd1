@{
    # Module manifest for PostgresBackup
    RootModule        = 'PostgresBackup.psm1'
    ModuleVersion     = '2.0.2'
    GUID              = '4f7b8a9c-2e6d-4b3a-9f8e-1c5a7d9b2e4f'
    Author            = 'Manoj Bhaskaran'
    CompanyName       = ''
    Description       = 'PostgreSQL database backup module with retention management and service control'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Backup-PostgresDatabase')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('postgresql','backup','database','retention','pg_dump')
            ProjectUri   = ''
            ReleaseNotes = '2.0.2: Fixed .pgpass authentication by using standard pg_dump options instead of connection string when no password is provided.'
        }
    }
}
