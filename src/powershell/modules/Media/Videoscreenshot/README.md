# Video Screenshot (PowerShell)

This project captures frames from videos via VLC and (optionally) runs a Python cropper to trim borders by dominant color.

## Quick Start
```powershell
Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots
```

## Common Use Cases
1. **Batch snapshot extraction** – export a few frames per second from multiple videos using VLC snapshots.
   ```powershell
   Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 1 -UseVlcSnapshots
   ```
2. **Desktop/GDI capture for screen recordings** – capture playback via GDI when VLC snapshots are unavailable.
   ```powershell
   Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -GdiFullscreen -TimeLimitSeconds 10
   ```
3. **Crop-only cleanup runs** – rerun the Python cropper without capturing new frames.
   ```powershell
   Start-VideoBatch -CropOnly -SaveFolder .\shots -PythonScriptPath .\src\python\crop_colours.py -ReprocessCropped
   ```
4. **Extension-filtered processing** – restrict work to specific formats and verify playability.
   ```powershell
   Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -IncludeExtensions '.mp4','.mkv' -VerifyVideos
   ```
5. **Resumable large runs** – skip previously processed items using the processed log file.
   ```powershell
   Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -ProcessedLogPath .\shots\.processed_videos.txt
   ```

## Parameters
- `SourceFolder` (string, required for capture): Root folder containing input videos.
- `SaveFolder` (string, required): Destination folder for captured frames or cropper input.
- `FramesPerSecond` (int, default module config): Target capture rate (1–60).
- `UseVlcSnapshots` (switch): Enable VLC scene snapshots; omit to use GDI capture.
- `GdiFullscreen` (switch): Ask VLC to run fullscreen/top-most during GDI capture.
- `TimeLimitSeconds` (int, default config): Per-video capture duration; `0` uses module default.
- `VideoLimit` (int, default `0`): Maximum number of videos to process (0 = all).
- `IncludeExtensions` (string[]): Extensions to consider (overrides defaults).
- `VerifyVideos` (switch): Attempt lightweight playability checks before processing.
- `RunCropper` (switch): Invoke the Python cropper after capture.
- `CropOnly` (switch): Run the cropper without taking screenshots.
- `PythonScriptPath` (string): Path to `crop_colours.py` when cropping.
- `PythonExe` (string): Python interpreter to use for the cropper.
- `ReprocessCropped` (switch): Force re-crop even if images were processed before.
- `KeepExistingCrops` (switch): Preserve existing crops when reprocessing.
- `ProcessedLogPath` (string): Location of the processed/resume log under `SaveFolder` by default.

## Error Handling
```powershell
try {
    Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots -RunCropper
}
catch {
    Write-Error "Video screenshot run failed: $_"
    # Inspect on-screen VLC/cropper logs for root cause (network paths, missing VLC/Python, etc.)
}
```

## Performance Considerations
- VLC snapshot mode generally outperforms GDI capture; prefer `-UseVlcSnapshots` when VLC is available.
- Set `FramesPerSecond` conservatively for long runs to reduce I/O and disk usage.
- Enable `-IncludeExtensions` to skip unsupported formats early and speed up discovery.
- Processed logs allow resumable runs—point `-ProcessedLogPath` at fast storage to avoid lock contention.
- Cropper runs can be CPU intensive; use `-VideoLimit`/`-TimeLimitSeconds` to batch work into smaller chunks.

## Usage
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

```powershell
Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots
```

### Cropper integration
When `-RunCropper` is set, the module invokes the Python cropper after capture. By default the cropper **skips images that were already cropped in previous runs** (tracked via `.processed_images`).

- **If `-PythonScriptPath` is provided** (path to `crop_colours.py`), the script file is executed directly.
- **If `-PythonScriptPath` is omitted**, the module falls back to **module invocation**:
  ```
  python -m crop_colours --input <SaveFolder> --skip-bad-images --allow-empty --recurse --preserve-alpha
  ```
  Ensure `crop_colours` is importable (e.g., installed or discoverable via `PYTHONPATH`).

To force a full re-crop, use:
```
Start-VideoBatch ... -RunCropper -ReprocessCropped         # deletes existing crops then regenerates
Start-VideoBatch ... -RunCropper -ReprocessCropped -KeepExistingCrops   # keeps existing crops; adds new alongside
```

If you call `Start-VideoBatch -Debug`, `--debug` is added to the Python invocation for verbose logging. The cropper’s stdout/stderr are **always streamed live to the console**, and Ctrl+C cancels cleanly.

#### Crop-only mode
Run the cropper without taking screenshots:
```powershell
Start-VideoBatch -CropOnly -SaveFolder .\shots -PythonScriptPath .\src\python\crop_colours.py
```
Notes:
- `-CropOnly` ignores capture-related parameters (e.g., `-UseVlcSnapshots`, `-TimeLimitSeconds`); a warning lists any that were supplied.
- The cropper operates on images under `-SaveFolder`.

Notes:
- The cropper receives absolute paths and streams logs to the console; Ctrl+C cancels cleanly.
- On failure, the module throws a concise error; see on-screen logs for details.

### Crop-only mode
Skip screenshot capture and only run the cropper:
```powershell
Start-VideoBatch -CropOnly -SaveFolder .\shots [-PythonScriptPath .\src\python\crop_colours.py]
```
Requirements/behavior:
- **`-SaveFolder` is required** in crop-only mode and must point to the folder containing images to process.
- `-SourceFolder` and other capture-related flags are **ignored** in crop-only mode.
- Use `-ReprocessCropped` (and optionally `-KeepExistingCrops`) to control re-cropping semantics.

### Advanced usage

#### Custom video extensions & preflight video verification
```powershell
Import-Module .\src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
  -Start-VideoBatch `
  -SourceFolder .\videos `
  -SaveFolder .\shots `
  -FramesPerSecond 2 `
  -UseVlcSnapshots `
  -IncludeExtensions '.mp4','.mkv','.webm' `
  -VerifyVideos
```
* -IncludeExtensions overrides the discovery set (defaults come from module config).
* -VerifyVideos attempts a lightweight playability check if Test-VideoPlayable is available; otherwise it logs a warning and skips verification.

#### What the cropper flags do
* --preserve-alpha — consider transparency when trimming borders; useful for PNGs with transparent edges.
* --allow-empty — treat an empty input as success (exit code 0).
* (reprocessing) Default behavior skips previously cropped images.
  - `--reprocess-cropped` reprocesses everything.
  - `--keep-existing-crops` (with `--reprocess-cropped`) keeps existing outputs; new files are de-duplicated.
See the Python script’s docstring for advanced options: src/python/crop_colours.py.

### Resume / processed logging

The module tracks which videos have been handled so future runs can skip work.

**Supported formats (both accepted):**

* **TSV (current, default for new writes)**
  Each line is `<FullPath>\t<Status>[\t<Reason>]`:
  ```
  C:\path\to\video1.mp4\tProcessed
  C:\path\to\video2.mp4\tSkipped\tnot playable
  ```

* **Legacy (single-column)**
  Each line is just the full path:
  ```
  C:\path\to\video1.mp4
  C:\path\to\video2.mp4
  ```

**Location**
- Default: `<SaveFolder>\.processed_videos.txt` (override with `-ProcessedLogPath`).

**Behavior**
- Entries are normalized to absolute provider paths at import time.
- On Windows, matching is case-insensitive to minimize false mismatches.
- Mixing TSV and legacy lines in the same file is supported; new writes use TSV.

**Legacy wrapper (decommissioned)**
The legacy `src\powershell\videoscreenshot.ps1` wrapper (now `Show-VideoscreenshotDeprecation.ps1`) has been **removed**.
Please import the module and call `Start-VideoBatch` directly:
```powershell
Import-Module src\powershell\module\Videoscreenshot\Videoscreenshot.psd1
Start-VideoBatch -SourceFolder .\videos -SaveFolder .\shots -FramesPerSecond 2 -UseVlcSnapshots
```

## Wrapper status
The legacy `videoscreenshot.ps1` wrapper (renamed to `Show-VideoscreenshotDeprecation.ps1`) has been **removed** in v3.0.0.
Invoking it now prints guidance to use `Start-VideoBatch` and exits with a non-zero code.

## Directory layout

```
src/
  powershell/
    Show-VideoscreenshotDeprecation.ps1 (decommissioned; prints guidance and exits)
    module/
      Videoscreenshot/
        Videoscreenshot.psd1            (module manifest)
        Videoscreenshot.psm1            (module loader)
        Public/
          Start-VideoBatch.ps1          (public entrypoint)
        Private/
          Logging.ps1                   (Write-Message; timestamped logging with stream selection)
          IO.Helpers.ps1                (file I/O helpers; safe append with retry; folder writability)
          Config.ps1                    (Get-DefaultConfig; central defaults incl. VideoExtensions, timings, Python pkgs)
          Env.Guards.ps1                (pwsh 7+ guard and env checks)
          New-RunContext.ps1            (per-run context: version, config, stats, run GUID)
          PidRegistry.ps1               (PID registry helpers for child VLC processes)
          Vlc.Process.ps1               (VLC arg building + start/stop)
          Snapshot.Monitor.ps1          (wait for snapshot frames; measure throughput & elapsed)
          Gdi.Capture.ps1               (desktop capture path; GDI+/System.Drawing on Windows)
          Cropper.Invoke.ps1            (Python cropper integration with optional auto-install of deps)
          Processed.Log.ps1             (processed/resume file support; TSV logging)
          Core.Outcome.ps1              (exit-code mapping and run outcome helpers)
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
- -RunCropper – after capture, run the Python cropper over the output images
- -PythonScriptPath – path to crop_colours.py when using -RunCropper
- -PythonExe – optional Python interpreter to use (defaults to py launcher or python)
- -NoAutoInstall – disable automatic installation of missing Python packages (see below)
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
- -ReprocessCropped – force re-crop even if images were processed previously (deletes existing crops by default)
- -KeepExistingCrops – with -ReprocessCropped, keep existing crops and add new outputs alongside
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
- VLC 3.x+ on PATH (vlc.exe) — snapshot mode is cross-platform where VLC is available.
- Python 3.8+ only needed when running the cropper.
- GDI capture is Windows-only (uses GDI+/System.Drawing). Prefer VLC snapshot mode on non-Windows systems
### Cropper dependencies & auto-install
When -RunCropper is used, the module preflights Python and required packages for the default cropper:

- Packages (configurable):
  - opencv-python — image I/O/decoding/encoding and basic pixel ops used for border trimming
  - numpy — efficient array operations supporting crop calculations
- Source of truth: Get-DefaultConfig().Python.RequiredPackages

If any package is missing, the module automatically installs them via python -m pip install by default.
- To disable this behavior, pass -NoAutoInstall. Missing packages will then raise a clear error with a suggested pip command.

> Tip: You can change the required package list by editing Config.ps1 (Python.RequiredPackages). This keeps the PowerShell code free of hard-coded package names.

> Note: The cropper’s stdout/stderr always stream live to the console; Ctrl+C cancels cleanly.
> For advanced control over cropping arguments, adjust the Python script directly.
> The module uses safe defaults: `--skip-bad-images --allow-empty --recurse --preserve-alpha`,
> and adds `--reprocess-cropped` (plus `--keep-existing-crops`) when you pass the corresponding PowerShell flags.
> Note: The cropper’s stdout/stderr stream live to the console (always-on). For advanced control over cropping arguments, adjust the Python script directly. The module uses safe defaults: `--skip-bad-images --allow-empty --recurse --preserve-alpha`, and adds `--reprocess-cropped` (plus `--keep-existing-crops`) when you pass the corresponding PowerShell flags.
- GDI capture currently targets Windows (uses GDI+/System.Drawing); VLC snapshot mode is cross-platform where VLC is available.
> See also the docstring in src/python/crop_colours.py for a full list of cropper flags, behaviors, and troubleshooting notes.
### If you see a version error
The script/module will refuse to run under Windows PowerShell (5.1/Desktop).
Install PowerShell 7+ and re-run using pwsh.

- winget install --id Microsoft.PowerShell -e +
On Windows (example):
`+`powershell +winget install --id Microsoft.PowerShell -e +`

## Troubleshooting
- “VLC not found”: ensure `vlc --version` runs in the same session.
- “Module not found”: verify the path to `Videoscreenshot.psd1` when importing the module manually.
- “Cropper failed due to missing packages”: by default, the module tries to install them. If you used -NoAutoInstall, install manually with python -m pip install <packages> or remove the switch.
- “Resume/processed not working”: the module reads `<SaveFolder>\.processed_videos.txt` and accepts **both**
  TSV (`<FullPath>\t<Status>[\t<Reason>]`) **and** legacy single-column (`<FullPath>`) lines. Paths are
  normalized to absolute; on Windows matching is case-insensitive. You can also point to an existing file
  via `-ProcessedLogPath`. `Start-VideoBatch` honors `-ResumeFile` by skipping items up to that file.
- **Crash: “There is no Runspace available to run scripts in this thread.”**
  This was caused by emitting PowerShell debug output from background stream handlers.
  Fixed in the next patch release; update to the latest version. As a temporary workaround,
  run without `-Debug`. Note that, by design, VLC’s stdout/stderr are still captured for errors,
  but per-line live output from VLC is no longer shown when `-Debug` is used.

### GDI-specific tips
- Prefer the Primary display; multi-monitor/VM environments may vary in behavior.
- If GDI capture is unreliable, try VLC snapshot mode (-UseVlcSnapshots) which is less dependent on desktop state.

## Performance tips
- For large image sets, tune the cropper’s --max-workers (I/O-bound workloads often benefit up to the number of cores; start modestly).
- Place -SaveFolder on a fast local SSD to reduce write bottlenecks.
- Use -VideoLimit for quick smoke tests before running the full batch.
---

For module history, see this folder’s `CHANGELOG.md`. For repository-wide changes, see the root `CHANGELOG.md`.

### Notes on timings
Runtime measurements reported by the cropper use wall-clock time (not CPU time) to better reflect I/O-bound workloads.
