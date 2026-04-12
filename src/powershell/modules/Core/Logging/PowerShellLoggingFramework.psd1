@{
    # Module manifest for PowerShellLoggingFramework
    RootModule        = 'PowerShellLoggingFramework.psm1'
    ModuleVersion     = '2.0.1'
    GUID              = '3c8d5e2a-9f4b-4e6c-8d7a-5b9c3f6e1a2d'
    Author            = 'Manoj Bhaskaran'
    CompanyName       = ''
    Description       = 'Cross-platform structured logging framework with support for multiple log levels and JSON output'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Initialize-Logger',
        'Write-LogDebug',
        'Write-LogInfo',
        'Write-LogWarning',
        'Write-LogError',
        'Write-LogCritical',
        'Get-LogWarningCount',
        'Get-LogErrorCount',
        'Reset-LogCounters'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('logging','framework','structured-logging','json','cross-platform')
            ProjectUri   = ''
            ReleaseNotes = '2.0.1: Added framework warning/error counter APIs for consumer scripts and modules.'
        }
    }
}
