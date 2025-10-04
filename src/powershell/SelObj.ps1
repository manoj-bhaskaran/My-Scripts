<#
.SYNOPSIS
This PowerShell script selects and opens a random file from a random subfolder or the main target folder in the specified directory.

.VERSION
2.1.1

# Changelog
## [2.1.1] — 04-10-2025
### Fixed
- Fixed PowerShell syntax error where param block was not positioned correctly after script metadata assignment, causing "param is not recognized" error.

## [2.1.0] — 04-10-2025
### Added
- Documentation now explicitly states **only `.jpg`, `.jpeg`, `.png`** images are considered.
- New sections: **Setup/Configuration**, **Troubleshooting**, and **FAQ**.
- Examples expanded (default run, custom path, invalid path handling, and how to extend allowed extensions).
- `Invoke-Item` wrapped in `try/catch` with user-friendly warning.
### Changed
- Inline comments clarify guards, filters, and extension list usage.
- Limitations updated with image-only scope and performance notes for huge directories.

## [2.0.0] — 04-10-2025
### Changed
- **Breaking:** Only `.jpg`, `.jpeg`, and `.png` files are considered as candidates for opening.
- Default documentation path now consistently points to `D:\...`.
- Avoids using `-Force` for folder/file enumeration and standardises attribute checks with `-band`.
- Adds guards for missing/invalid target path and empty candidate folders/files.

## [1.0.0] — 31-05-2025
### Added
- Initial release of `SelObj.ps1`: selects a random subfolder (or the main target folder if it has files) and then opens a random non-hidden, non-system file from that location.

.DESCRIPTION
The script first checks for subfolders in the specified target directory. If subfolders are found, it randomly selects one of them. If there are image files in the main target folder, it includes the main folder in the list of subfolders. It then randomly selects **an image file only** (`.jpg`, `.jpeg`, `.png`) from the chosen folder to open. Files of other types are ignored by design.

.PARAMETER FilePath
Optional. Specifies the path to the target directory where the files are located. Defaults to "D:\users\Manoj\Documents\FIFA 07\elib".

.EXAMPLE
**All examples select only image files** (`.jpg`, `.jpeg`, `.png`):

1) Default run (images only):
   .\SelObj.ps1

2) Custom path (images only):
   .\SelObj.ps1 -FilePath "D:\Custom\Path"

3) Handling invalid path (sample error output):
   PS> .\SelObj.ps1 -FilePath "D:\Does\Not\Exist"
   Target path not found or not a directory: D:\Does\Not\Exist

4) Extending allowed extensions (snippet inside the script):
   # Add more types (e.g., GIF, WEBP) by editing $allowedExt:
   $allowedExt = '.jpg','.jpeg','.png','.gif','.webp'

.NOTES
Script Workflow:
1. **Initialization**:
   - Defines the target directory using the provided parameter or defaults to the specified path.
   
2. **Subfolder Management**:
   - Gets all **visible** (non-hidden, non-system) subfolders in the target directory.
   - Checks if there are **image files** in the main target folder and includes it in the list of subfolders if applicable.

3. **File Selection**:
   - Selects a random folder from the list of subfolders (including the main target folder if it has image files).
   - Selects a random **image file** from the chosen folder.

4. **Error Handling**:
   - Logs a message if no image files are found in the selected folder or the target directory and surfaces a clear warning if opening fails.

Setup/Configuration:
- Default path: `D:\users\Manoj\Documents\FIFA 07\elib`.
- Requires that suitable image viewers are installed and that the user has read/execute permissions on target files.

Troubleshooting:
- **Path not found**: Ensure `-FilePath` exists and is a directory.
- **No images found**: Confirm the folder(s) contain `.jpg/.jpeg/.png` files and are not hidden/system-only.

FAQ:
- **How do I include more extensions?** Edit `$allowedExt` in the script (see example above).
- **How is the file chosen?** A random eligible folder is selected, then a random eligible image file from within it.

Limitations:
- The script only processes top-level files and subfolders within the target directory, and **only image files** (`.jpg/.jpeg/.png`) are considered.
- Large directories with many subfolders/images may impact performance; consider pre-indexing, sampling, or adding filters to narrow scope.
#>

param(
    [string]$FilePath = "D:\users\Manoj\Documents\FIFA 07\elib"
)

# Script metadata
# Expose version programmatically for logs/tests if needed.
$Script:ScriptVersion = '2.1.1'

# Get all subfolders
# --- Hardening & image-only behavior (2.0.0) ---
# Guard: target path must exist
if (-not (Test-Path -Path $FilePath -PathType Container)) {
    throw "Target path not found or not a directory: $FilePath"
}

# EXTENSION LIST (image-only): lower-case compare.
# To include more types (e.g., .gif, .webp), append to this list.
$allowedExt = '.jpg','.jpeg','.png'

# Get all visible (non-hidden/system) subfolders under target (no -Force)
# (Folders: hidden/system excluded by default; adjust if you wish to include them.)

$subfolders = Get-ChildItem -Path $FilePath -Directory |
    Where-Object { -not (($_.Attributes -band [IO.FileAttributes]::Hidden) -or ($_.Attributes -band [IO.FileAttributes]::System)) }

# Check if there are any files in the main target folder
$mainFolderFiles = Get-ChildItem -Path $FilePath -File |
    Where-Object {
        -not (($_.Attributes -band [IO.FileAttributes]::Hidden) -or ($_.Attributes -band [IO.FileAttributes]::System)) -and
        ($allowedExt -contains $_.Extension.ToLower())
    }
if ($mainFolderFiles.Count -gt 0) {
    # Add the main target folder to the list of subfolders
    $subfolders += Get-Item -Path $FilePath
}

# Select a random folder (including the main target folder if applicable)
if (-not $subfolders) {
    Write-Warning "No candidate folders found under '$FilePath' (visible, non-system)."
    return
}
$randomFolder = $subfolders | Get-Random

# Get all files from the random folder excluding hidden and system files
# (Files: enforce image-only and exclude hidden/system attributes.)
$files = Get-ChildItem -Path $randomFolder.FullName -File |
    Where-Object {
        -not (($_.Attributes -band [IO.FileAttributes]::Hidden) -or ($_.Attributes -band [IO.FileAttributes]::System)) -and
        ($allowedExt -contains $_.Extension.ToLower())
    }

# Check if there are any files in the selected folder
if ($files.Count -gt 0) {
    # Select a random file and open it
    $randomFile = $files | Get-Random
    # Opening the selected image; wrap in try/catch for user-friendly feedback
    try {
        Invoke-Item $randomFile.FullName
    }
    catch {
        Write-Warning ("Failed to open '{0}': {1}" -f $randomFile.FullName, $_.Exception.Message)
    }
} else {
    Write-Host "No image files found in the randomly selected folder: $($randomFolder.FullName)"
}
