# Media Processing Scripts

Scripts for image and video processing, conversion, and manipulation.

## Scripts

- **ConvertTo-Jpeg.ps1** - Converts images to JPEG format
- **Convert-ImageFile.ps1** - General-purpose image format conversion
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

# General format conversion
.\Convert-ImageFile.ps1 -Source "image.png" -OutputFormat "jpg"
```

## Video Screenshot Module

The Videoscreenshot module has been moved to `src/powershell/modules/Media/Videoscreenshot/`. See the deprecation script for migration details.

## Logging

All scripts use the PowerShell Logging Framework and write logs to the standard logs directory.
