# Video Screenshot (PowerShell)
 
This project captures frames from videos via VLC and (optionally) runs a Python cropper to trim borders by dominant color.
 
## Usage
Run `videoscreenshot.ps1` with your desired parameters.
## What changed in v1.3.0 (modularization)
We split the monolithic `videoscreenshot.ps1` into a **PowerShell module** to improve testability and aintainability. The legacy script remains as a **thin wrapper** for back-compat.

### New command
```powershell
Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots
```

The wrapper `videoscreenshot.ps1` still works but will emit a deprecation warning and forwards to `Start-VideoBatch`.

## Directory layout

```
src/
  powershell/
    videoscreenshot.ps1                 # legacy entrypoint (thin wrapper)
    module/
      Videoscreenshot/
        Videoscreenshot.psd1            # module manifest
        Videoscreenshot.psm1            # module loader
        Public/
          Start-VideoBatch.ps1          # public cmdlet (orchestrator)
        Private/
          Config.ps1                    # version + config constants
          Logging.ps1                   # Write-Message
          IO.Helpers.ps1                # Add-ContentWithRetry, Test-FolderWritable
          PidRegistry.ps1               # PID registry helpers
          Vlc.Process.ps1               # VLC arg building + start/stop
          Core.Outcome.ps1              # Resolve-Outcome (used in later PRs)
```

> NOTE: Follow-up PRs will move more helpers (GDI capture, snapshot monitor, metadata/COM, cropper integration) into `Private/`.

## Usage (wrapper)
```powershell
pwsh -NoProfile -File .\src\powershell\videoscreenshot.ps1 `
  -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots
```

## Requirements
- VLC (`vlc.exe`) on PATH
- PowerShell 5.1+ (Windows) or PowerShell 7+ (Core)
- Python only needed when running the cropper (moved in later PRs)

## Troubleshooting
- “VLC not found”: ensure `vlc --version` runs in the same session.
- “Module not found”: verify the path to `Videoscreenshot.psd1` when importing the module manually.

---

For the historical changelog prior to 1.3.0, see inline comments in earlier tags; ongoing changes are tracked in `CHANGELOG.md`.
