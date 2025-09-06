@{
  RootModule        = 'Videoscreenshot.psm1'
  ModuleVersion     = '1.3.0'
  GUID              = '7a5f7b2d-5d7b-4b63-9f25-ef6d6b4f9b2f'
  Author            = 'Manoj Bhaskaran'
  CompanyName       = ''
  CompatiblePSEditions = @('Desktop','Core')
  Description       = 'Modularized video frame capture (VLC/GDI+) with Python cropper integration.'
  PowerShellVersion = '5.1'
  FunctionsToExport = @('Start-VideoBatch')
  AliasesToExport   = @()
  CmdletsToExport   = @()
  VariablesToExport = '*'
  PrivateData       = @{ PSData = @{ } }
}
