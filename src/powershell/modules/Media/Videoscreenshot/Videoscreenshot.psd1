@{
  RootModule        = 'Videoscreenshot.psm1'
  ModuleVersion     = '3.4.1'
  GUID              = '7a5f7b2d-5d7b-4b63-9f25-ef6d6b4f9b2f'
  Author            = 'Manoj Bhaskaran'
  CompanyName       = ''
  CompatiblePSEditions = @('Core')
  Description       = 'Modularized video frame capture via VLC (snapshots) or GDI+ (desktop), with optional Python cropper integration. Typical formats: .mp4, .mkv, .avi, .mov, .m4v, .wmv. VLC on PATH or specify -VlcExe; Python is needed only when using the cropper.'
  PowerShellVersion = '7.0'
  RequiredModules   = @(
    @{ ModuleName = 'FileOperations'; ModuleVersion = '1.0.3' }
    @{ ModuleName = 'ErrorHandling';  ModuleVersion = '1.1.1' }
  )
  FunctionsToExport = @('Start-VideoBatch')
  AliasesToExport   = @()
  CmdletsToExport   = @()
  VariablesToExport = @()
  PrivateData       = @{
    PSData = @{
      Tags         = @('video','vlc','gdi','screenshots','crop','python','images','automation')
      ReleaseNotes = '3.4.1: Remove Private/IO.Helpers.ps1; resolve Test-FolderWritable and Add-ContentWithRetry from Core/FileOperations and replace inline Get-Command availability checks with Test-CommandAvailable from Core/ErrorHandling.
3.4.0: Add opt-out per-run logging for Start-VideoBatch via default SaveFolder logs, -LogFile override, and -NoLogFile opt-out. Write-Message now honors a module-scoped sink so helper messages land in the same run log.'
    }
  }
}
