@{
  RootModule        = 'Videoscreenshot.psm1'
  ModuleVersion     = '3.2.9'
  GUID              = '7a5f7b2d-5d7b-4b63-9f25-ef6d6b4f9b2f'
  Author            = 'Manoj Bhaskaran'
  CompanyName       = ''
  CompatiblePSEditions = @('Core')
  Description       = 'Modularized video frame capture via VLC (snapshots) or GDI+ (desktop), with optional Python cropper integration. Typical formats: .mp4, .mkv, .avi, .mov, .m4v, .wmv. VLC on PATH or specify -VlcExe; Python is needed only when using the cropper.'
  PowerShellVersion = '7.0'
  FunctionsToExport = @('Start-VideoBatch')
  AliasesToExport   = @()
  CmdletsToExport   = @()
  VariablesToExport = @()
  PrivateData       = @{
    PSData = @{
      Tags         = @('video','vlc','gdi','screenshots','crop','python','images','automation')
      ReleaseNotes = '3.2.9: Invoke-Cropper now sets the cropper child working directory to the selected src/python package root and passes an absolute input path so python -m resolves the intended media package before any caller cwd package.'
    }
  }
}
