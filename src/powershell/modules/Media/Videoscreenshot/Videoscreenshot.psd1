@{
  RootModule        = 'Videoscreenshot.psm1'
  ModuleVersion     = '3.6.2'
  GUID              = '7a5f7b2d-5d7b-4b63-9f25-ef6d6b4f9b2f'
  Author            = 'Manoj Bhaskaran'
  CompanyName       = ''
  CompatiblePSEditions = @('Core')
  Description       = 'Modularized video frame capture via VLC (snapshots) or GDI+ (desktop), with optional Python cropper integration. Typical formats: .mp4, .mkv, .avi, .mov, .m4v, .wmv. VLC on PATH or specify -VlcExe; Python is needed only when using the cropper.'
  PowerShellVersion = '7.0'
  RequiredModules   = @()
  FunctionsToExport = @('Start-VideoBatch')
  AliasesToExport   = @()
  CmdletsToExport   = @()
  VariablesToExport = @()
  PrivateData       = @{
    PSData = @{
      Tags         = @('video','vlc','gdi','screenshots','crop','python','images','automation')
      ReleaseNotes = '3.6.2: Extract Initialize-RunLogFile into Private/Logging.ps1, Get-ProcessedVideoSet into Private/Processed.Log.ps1, and Measure-CaptureFrameDelta into new Private/Capture.Metrics.ps1; Start-VideoBatch reduced by ~120 lines with no behaviour change.
3.6.1: Extract Resolve-VlcExecutable, Initialize-VlcSidecarLog, and Remove-TempRunFile helpers from Start-VideoBatch into Private/Vlc.Process.ps1; reduces orchestrator by ~85 lines.
3.6.0: Add -RetryUnplayable to re-attempt stale Skipped/NotPlayable resume-log entries after probe false-skips.
3.5.0: Add opt-in scene-change frame selection via FFmpeg with configurable threshold/backend defaults and VLC ratio fallback when FFmpeg is unavailable.
3.4.1: Remove Private/IO.Helpers.ps1; resolve Test-FolderWritable and Add-ContentWithRetry from Core/FileOperations and replace inline Get-Command availability checks with Test-CommandAvailable from Core/ErrorHandling.
3.4.0: Add opt-out per-run logging for Start-VideoBatch via default SaveFolder logs, -LogFile override, and -NoLogFile opt-out. Write-Message now honors a module-scoped sink so helper messages land in the same run log.'
    }
  }
}
