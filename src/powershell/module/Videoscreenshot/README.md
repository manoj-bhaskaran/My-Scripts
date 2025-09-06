# Video Screenshot (PowerShell)
 
This project captures frames from videos via VLC and (optionally) runs a Python cropper to trim borders by dominant color.
 
## Usage

**Recommended (module)**
```powershell
Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots
```

**Legacy wrapper (still supported)**
```powershell
pwsh -NoProfile -File .\src\powershell\videoscreenshot.ps1 `
  -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots
```

## What changed in v1.3.0 (modularization)
We split the monolithic `videoscreenshot.ps1` into a **PowerShell module** to improve testability and maintainability. The legacy script remains as a **thin wrapper** for back-compat.

The wrapper `videoscreenshot.ps1` still works but will emit a deprecation warning and forwards to `Start-VideoBatch`.

## Directory layout

```
src/
  powershell/
    videoscreenshot.ps1                 (legacy wrapper)
    videoscreenshot.util.psm1           (shared helpers for wrapper)
    module/
      Videoscreenshot/
        Videoscreenshot.psd1            (module manifest)
        Videoscreenshot.psm1            (module loader)
        Start-VideoBatch.ps1            (public entrypoint)
        Vlc.Process.ps1                 (VLC arg building + start/stop)
        IO.Helpers.ps1                  (file I/O helpers)
        PidRegistry.ps1                 (PID registry helpers)
        Logging.ps1                     (Write-Message)
        Config.ps1                      (version + config constants)
        Core.Outcome.ps1                (outcome helpers)
        CHANGELOG.md
        README.md
```

> NOTE: The current module uses a **flat layout** (files directly under `Videoscreenshot/`).  
> Follow-up PRs may introduce `Public/` and `Private/` subfolders as the implementation is completed
> (e.g., GDI capture, snapshot monitor, metadata/COM, cropper integration).

## Parameters (common)

- `-SourceFolder` – folder containing input videos (recursively searched)
- `-SaveFolder` – output folder for frames
- `-FramesPerSecond` – target FPS for capture (1–60)
- `-UseVlcSnapshots` – enable VLC scene snapshot mode; otherwise GDI capture is used
- `-GdiFullscreen` – when using GDI, request fullscreen/top-most playback
- `-VlcStartupTimeoutSeconds` – timeout for VLC to initialize

## Requirements
- VLC (`vlc.exe`) on PATH
- PowerShell 5.1+ (Windows) or PowerShell 7+ (Core)
- Python only needed when running the cropper (moved in later PRs)

## Troubleshooting
- “VLC not found”: ensure `vlc --version` runs in the same session.
- “Module not found”: verify the path to `Videoscreenshot.psd1` when importing the module manually.

---

For module history, see this folder’s `CHANGELOG.md`. For repository-wide changes, see the root `CHANGELOG.md`.
