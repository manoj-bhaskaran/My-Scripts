<#
.SYNOPSIS
This PowerShell script selects and opens a random file from a random subfolder in the specified target directory. If no subfolders are found, it selects a random file directly from the target directory.

.DESCRIPTION
The script first checks for subfolders in the specified target directory. If subfolders are found, it randomly selects one and then randomly selects a file from within that subfolder to open. If no subfolders are found, it randomly selects a file from the target directory itself.

.PARAMETER FilePath
Optional. Specifies the path to the target directory where the files are located. Defaults to "C:\users\Manoj\Documents\FIFA 07\elib".

.EXAMPLES
To select and open a random file from a subfolder (or the target directory if no subfolders exist) in the default target directory:
.\SelObj.ps1

To select and open a random file from a subfolder (or the target directory if no subfolders exist) in a custom target directory:
.\SelObj.ps1 -FilePath "C:\Custom\Path"

.NOTES
Script Workflow:
1. **Initialization**:
   - Defines the target directory using the provided parameter or defaults to the specified path.
   
2. **Subfolder Management**:
   - Gets all subfolders in the target directory.

3. **File Selection**:
   - If subfolders exist, selects a random subfolder and then selects a random file from that subfolder.
   - If no subfolders exist, selects a random file from the target directory.

4. **Error Handling**:
   - Logs a message if no files are found in the selected subfolder or the target directory.

Limitations:
- The script only processes top-level files and subfolders within the target directory.
#>

param(
    [string]$FilePath = "D:\users\Manoj\Documents\FIFA 07\elib"
)

# Get all subfolders
$subfolders = Get-ChildItem -Path $FilePath -Directory -Force

# Check if there are any subfolders
if ($subfolders.Count -gt 0) {
    # Select a random subfolder
    $randomSubfolder = $subfolders | Get-Random
    
    # Get all files from the random subfolder
    $files = Get-ChildItem -Path $randomSubfolder.FullName -File -Force

    # Check if there are any files in the selected subfolder
    if ($files.Count -gt 0) {
        # Select a random file and open it
        $randomFile = $files | Get-Random
        Invoke-Item $randomFile.FullName
    } else {
        Write-Host "No files found in the randomly selected subfolder: $($randomSubfolder.FullName)"
    }
} else {
    # No subfolders found, select a random file from the target directory
    $files = Get-ChildItem -Path $FilePath -File -Force
    if ($files.Count -gt 0) {
        # Select a random file and open it
        $randomFile = $files | Get-Random
        Invoke-Item $randomFile.FullName
    } else {
        Write-Host "No files found in the target directory: $FilePath"
    }
}
