@{
    RootModule        = 'AdbHelpers.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '067f1c0e-5a83-4f49-af4f-bc293167659e'
    Author            = 'Manoj Bhaskaran'
    CompanyName       = 'Unknown'
    Copyright         = '(c) 2026. All rights reserved.'
    Description       = 'Reusable Android ADB helper functions for device validation, remote shell execution, and remote file metadata queries.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Confirm-Device',
        'Get-RemoteFileCount',
        'Get-RemoteSize',
        'Invoke-AdbSh',
        'Test-Adb',
        'Test-HostTar',
        'Test-PhoneTar'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Android', 'ADB', 'Utilities', 'FileManagement')
            ProjectUri = 'https://github.com/manoj-bhaskaran/My-Scripts'
        }
    }
}
