<#
.SYNOPSIS
This PowerShell script selects and opens a random file from a random subfolder or the main target folder in the specified directory.

.VERSION
2.0.0

# Changelog
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
The script first checks for subfolders in the specified target directory. If subfolders are found, it randomly selects one of them. If there are files in the main target folder, it includes the main folder in the list of subfolders. It then randomly selects a file from the chosen folder to open.

.PARAMETER FilePath
Optional. Specifies the path to the target directory where the files are located. Defaults to "D:\users\Manoj\Documents\FIFA 07\elib".

.EXAMPLES
To select and open a random file from a subfolder or the main target folder in the default target directory:
.\SelObj.ps1

To select and open a random file from a subfolder or the main target folder in a custom target directory:
.\SelObj.ps1 -FilePath "D:\Custom\Path"

.NOTES
Script Workflow:
1. **Initialization**:
   - Defines the target directory using the provided parameter or defaults to the specified path.
   
2. **Subfolder Management**:
   - Gets all subfolders in the target directory.
   - Checks if there are files in the main target folder and includes it in the list of subfolders if applicable.

3. **File Selection**:
   - Selects a random folder from the list of subfolders (including the main target folder if it has files).
   - Selects a random file from the chosen folder.

4. **Error Handling**:
   - Logs a message if no files are found in the selected folder or the target directory.

Limitations:
- The script only processes top-level files and subfolders within the target directory.
#>

# Script metadata
# Expose version programmatically for logs/tests if needed.
$Script:ScriptVersion = '2.0.0'
 
param(
    [string]$FilePath = "D:\users\Manoj\Documents\FIFA 07\elib"
)

# Get all subfolders
# --- Hardening & image-only behavior (2.0.0) ---
# Guard: target path must exist
if (-not (Test-Path -Path $FilePath -PathType Container)) {
    throw "Target path not found or not a directory: $FilePath"
}

# Allowed image extensions (lower-case compare)
$allowedExt = '.jpg','.jpeg','.png'

# Get all visible (non-hidden/system) subfolders under target (no -Force)
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
$files = Get-ChildItem -Path $randomFolder.FullName -File |
    Where-Object {
        -not (($_.Attributes -band [IO.FileAttributes]::Hidden) -or ($_.Attributes -band [IO.FileAttributes]::System)) -and
        ($allowedExt -contains $_.Extension.ToLower())
    }

# Check if there are any files in the selected folder
if ($files.Count -gt 0) {
    # Select a random file and open it
    $randomFile = $files | Get-Random
    Invoke-Item $randomFile.FullName
} else {
    Write-Host "No files found in the randomly selected folder: $($randomFolder.FullName)"
}
