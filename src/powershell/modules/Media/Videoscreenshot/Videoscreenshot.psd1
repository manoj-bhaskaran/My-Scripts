@{
  RootModule        = 'Videoscreenshot.psm1'
  ModuleVersion     = '3.1.0'
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
      ReleaseNotes = '3.1.0: Duration-aware per-video snapshot cap: Start-VideoBatch now probes each video duration via ffprobe (falling back to Windows Shell) and uses cap = duration + SnapshotDurationGraceSeconds (default 30 s) instead of the flat 300 s constant. The flat fallback is retained when duration detection fails.'
    }
  }
}
