@{
    # Module manifest for PostgresBackup
    RootModule        = 'PostgresBackup.psm1'
    ModuleVersion     = '2.1.1'
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
            ReleaseNotes = '2.1.1: pg_dump auto-detection now compares versions across all Windows install roots (ProgramFiles and ProgramFiles(x86)) before selecting, so the newest major version always wins. 2.1.0: pg_dump path is now auto-detected (PGBACKUP_PGDUMP / PGBIN env vars, PATH, then standard Windows install roots) instead of being hardcoded, improving portability across machines.'
        }
    }
}
