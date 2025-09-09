# Video Screenshot (PowerShell)
 
This project captures frames from videos via VLC and (optionally) runs a Python cropper to trim borders by dominant color.
 
## Usage

**Recommended (module)**
```powershell
Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots
```
### GDI capture mode (desktop capture)

If you prefer GDI+ desktop capture instead of VLC’s snapshot filter, omit -UseVlcSnapshots:

```powershell
Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
Start-VideoBatch `
-SourceFolder .\videos `
-SaveFolder .\shots `
-FramesPerSecond 2 `
-GdiFullscreen `
-TimeLimitSeconds 5
```

Notes:
- Leaving -TimeLimitSeconds 0 uses the module’s default GDI duration from config.
- The run summary logs the number of frames saved and (when available) the achieved FPS.
- -GdiFullscreen asks VLC to run fullscreen/top-most to reduce desktop interference during capture.

### VLC snapshot mode (scene filter)

Use VLC’s scene snapshot filter to write frames directly to disk:

powershell +Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1 +Start-VideoBatch SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots 

### Cropper integration
- When `-RunCropper` is set, the module invokes the Python cropper as:
  ```
  python crop_colours.py --input <SourceFolder> --skip-bad-images --allow-empty --ignore-processed --recurse --preserve-alpha
  ```
  If you call `Start-VideoBatch -Debug`, the module also adds `--debug` to the Python invocation.
```

Notes:
- Python resolution order is: -PythonExe (if supplied), otherwise py (Windows launcher, invoked with -3), otherwise python.
- The cropper receives absolute paths for --folder and --prefix. It should not rely on current working directory.
- On failure, the module throws with the cropper’s STDERR (and STDOUT when present) to simplify debugging.

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
    module/
      Videoscreenshot/
        Videoscreenshot.psd1            (module manifest)
        Videoscreenshot.psm1            (module loader)
        Public/
          Start-VideoBatch.ps1          (public entrypoint)
        Private/
          Logging.ps1                   (Write-Message)
          IO.Helpers.ps1                (file I/O helpers)
          Config.ps1                    (Get-DefaultConfig; config defaults)
          Env.Guards.ps1                (pwsh 7+ guard and env checks)
          New-RunContext.ps1            (state isolation: build per-run context)
          PidRegistry.ps1               (PID registry helpers)
          Vlc.Process.ps1               (VLC arg building + start/stop)
          Snapshot.Monitor.ps1          (wait/measure scene snapshots)
          Gdi.Capture.ps1               (desktop capture path)
          Cropper.Invoke.ps1            (Python cropper integration)
          Processed.Log.ps1             (processed/resume file support)
          Core.Outcome.ps1              (outcome helpers)
        CHANGELOG.md
        README.md
```

> NOTE: The module now uses explicit Public/ and Private/ subfolders. Additional internals may be added under Private/ as features evolve.

## Parameters (common)

- -SourceFolder – folder containing input videos (recursively searched)
- -SaveFolder – output folder for frames
- -FramesPerSecond – target FPS for capture (1–60)
- -UseVlcSnapshots – enable VLC scene snapshot mode; otherwise GDI capture is used
- -GdiFullscreen – when using GDI, request fullscreen/top-most playback
- -VlcStartupTimeoutSeconds – timeout for VLC to initialize
- -TimeLimitSeconds – per-video time cap for playback/capture (0 = no cap)
- -VideoLimit – limit how many videos to process in this run (0 = all)
- **Resume / processed logging (P0)**
- -ProcessedLogPath – path to append successfully processed videos (defaults under -SaveFolder)
- -ResumeFile – optional list of already-processed video paths to skip
- **Advanced timing (P0)**
- -MaxPerVideoSeconds – hard ceiling for wait/monitor phases (snapshots)
- -StartupGraceSeconds – grace delay after VLC start before measuring
- **Cropper**
- -RunCropper – run Python cropper after frames saved
- -PythonScriptPath, -PythonExe – cropper script & interpreter
- -ClearSnapshotsBeforeRun – clear existing frames for the current video prefix before capture

### Example (with resume + processed logging)
```powershell
Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
Start-VideoBatch `
-SourceFolder .\videos `
-SaveFolder .\shots `
-UseVlcSnapshots `
-FramesPerSecond 2 `
-ProcessedLogPath .\shots\processed.log `
-ResumeFile .\shots\processed.log `
-MaxPerVideoSeconds 120 `
-StartupGraceSeconds 2
```
## Requirements
- PowerShell 7.0+ (PSEdition Core, a.k.a. pwsh) — Windows PowerShell 5.1 is not supported as of v2.0.0.
- VLC (`vlc.exe`) on PATH
- Python only needed when running the cropper.
- GDI capture currently targets Windows (uses GDI+/System.Drawing); VLC snapshot mode is cross-platform where VLC is available.
### If you see a version error
The script/module will refuse to run under Windows PowerShell (5.1/Desktop).
Install PowerShell 7+ and re-run using pwsh.

- winget install --id Microsoft.PowerShell -e +
On Windows (example):
`+`powershell +winget install --id Microsoft.PowerShell -e +`

## Troubleshooting
- “VLC not found”: ensure `vlc --version` runs in the same session.
- “Module not found”: verify the path to `Videoscreenshot.psd1` when importing the module manually.

---

For module history, see this folder’s `CHANGELOG.md`. For repository-wide changes, see the root `CHANGELOG.md`.

### Notes on timings
Runtime measurements reported by the cropper use wall-clock time (not CPU time) to better reflect I/O-bound workloads.
