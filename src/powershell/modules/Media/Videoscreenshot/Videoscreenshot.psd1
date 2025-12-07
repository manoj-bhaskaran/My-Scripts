@{
  RootModule        = 'Videoscreenshot.psm1'
  ModuleVersion     = '3.0.3'
  GUID              = '7a5f7b2d-5d7b-4b63-9f25-ef6d6b4f9b2f'
  Author            = 'Manoj Bhaskaran'
  CompanyName       = ''
  CompatiblePSEditions = @('Core')
  Description       = 'Modularized video frame capture via VLC (snapshots) or GDI+ (desktop), with optional Python cropper integration. Typical formats: .mp4, .mkv, .avi, .mov, .m4v, .wmv. Requires VLC on PATH; Python is needed only when using the cropper.'
  PowerShellVersion = '7.0'
  FunctionsToExport = @('Start-VideoBatch')
  AliasesToExport   = @()
  CmdletsToExport   = @()
  VariablesToExport = @()
  PrivateData       = @{
    PSData = @{
      Tags         = @('video','vlc','gdi','screenshots','crop','python','images','automation')
      ReleaseNotes = '3.0.3: Fixed empty catch blocks in error handling (added explanatory comments for resource cleanup, process termination).'
    }
  }
}
