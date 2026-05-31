@{
  RootModule        = 'Videoscreenshot.psm1'
  ModuleVersion     = '3.3.0'
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
      ReleaseNotes = '3.3.0: Add -DeduplicateFrames opt-in switch that removes consecutive identical snapshot frames by content hash (SHA256 default); frame counts and status logging reflect kept frames. Config knob DeduplicateHashAlgorithm allows algorithm override.'
    }
  }
}
