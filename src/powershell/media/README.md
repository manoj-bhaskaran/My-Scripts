# Media Processing Scripts

Scripts for image and video processing, conversion, and manipulation.

## Scripts

- **ConvertTo-Jpeg.ps1** - Converts images to JPEG format
- **Move-ImageFileToBatch.ps1** - Renames .jpeg/.jpg_large to .jpg and moves files into per-extension, size-limited subfolders
- **Show-RandomImage.ps1** - Displays a random image from a specified directory
- **Show-VideoscreenshotDeprecation.ps1** - Videoscreenshot module deprecation notice and migration guide

## Dependencies

### PowerShell Modules
- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging
- **Videoscreenshot** (`src/powershell/modules/Media/Videoscreenshot/`) - Video frame capture functionality

### External Tools
- .NET imaging libraries (System.Drawing)
- VLC Media Player (for Videoscreenshot module)
- PowerShell 5.1 or later

## Image Conversion

The conversion scripts support various image formats including:
- JPEG/JPG
- PNG
- BMP
- GIF
- TIFF

### Usage Example
```powershell
# Convert images to JPEG
.\ConvertTo-Jpeg.ps1 -Path "C:\Images" -Quality 90

# Organise images into batched subfolders
.\Move-ImageFileToBatch.ps1 -SourceDir "D:\Photos" -DestDir "F:\Media" -ShowProgress
```

## Video Screenshot Module

The Videoscreenshot module has been moved to `src/powershell/modules/Media/Videoscreenshot/`. See the deprecation script for migration details.

## Logging

All scripts use the PowerShell Logging Framework for structured logging.

### Move-ImageFileToBatch.ps1

Use `-LogDirectory` to control where log files are written:

- **With `-LogDirectory`**: both the framework log and the per-run error log (when errors occur)
  are written to the supplied directory, which is created if it does not exist.
- **Without `-LogDirectory`**: the framework log goes to its default location (relative to the
  module); any error log is auto-created under `-DestDir` as
  `picconvert_errors_yyyyMMdd_HHmmss.log`.

```powershell
.\Move-ImageFileToBatch.ps1 -SourceDir "D:\Photos" -DestDir "F:\Media" `
    -LogDirectory "C:\Logs\picconvert" -ShowProgress
```
