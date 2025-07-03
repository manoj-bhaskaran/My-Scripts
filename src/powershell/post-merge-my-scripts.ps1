<#
.SYNOPSIS
This PowerShell script automates the process of pulling the main branch from the GitHub repository, comparing files with a specified directory, and distributing newer files to a target directory.

.DESCRIPTION
The script pulls the latest changes from the GitHub repository, compares the files in the local repository with those in a specified comparison directory, and copies newer files to the target directory.

.PARAMETER localRepoPath
Path to the local Git repository.

.PARAMETER compareDirectory
Path to the directory to compare files with.

.PARAMETER targetDirectory
Path to the directory where newer files will be copied.

.EXAMPLES
To run the script manually:
.\post-merge-my-scripts.ps1

.NOTES
1. Define paths for the local repository, comparison directory, and target directory.
2. Implement functionality to pull the latest changes from the main branch.
3. Compare files in the local repository with those in the comparison directory.
4. Copy newer files to the target directory.

#>

# Define paths
$localRepoPath = "D:\My Scripts"
$compareDirectory = "C:\Users\manoj\Documents\Scripts"
$targetDirectory = "C:\Users\manoj\Documents\Scripts"
$logFile = "C:\Users\manoj\Documents\Scripts\git-post-action.log"

# Function to log messages with timestamps and source identifier
function Log-Message {
    param (
        [string]$message,
        [string]$source = "post-merge"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$source] $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry
}

Log-Message "Script execution started."

# Pull the latest changes from the main branch
Log-Message "Pulling latest changes from the main branch..."
Set-Location -Path $localRepoPath
git pull origin main | ForEach-Object { Log-Message $_ }

# Function to compare and copy newer files
function Compare-And-Copy {
    param (
        [string]$source,
        [string]$destination,
        [string]$target
    )

    Get-ChildItem -Path $source -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($source.Length)
        $compareFilePath = Join-Path $destination $relativePath
        $targetFilePath = Join-Path $target $relativePath

        if (-not (Test-Path -Path $compareFilePath)) {
            Log-Message "New file: $relativePath"
            Copy-Item -Path $_.FullName -Destination $targetFilePath -Force
            Log-Message "Copied new file $relativePath to $target"
        } elseif ((Get-Item -Path $_.FullName).LastWriteTime -gt (Get-Item -Path $compareFilePath).LastWriteTime) {
            Log-Message "Updated file: $relativePath"
            Copy-Item -Path $_.FullName -Destination $targetFilePath -Force
            Log-Message "Copied updated file $relativePath to $target"
        }
    }
}

# Compare and copy newer files
Log-Message "Comparing files and copying newer ones to target directory..."
Compare-And-Copy -source $localRepoPath -destination $compareDirectory -target $targetDirectory

# Deploy PowerShell modules listed in the configuration file
Log-Message "Deploying PowerShell modules from module-deployment-config.txt..."
$configPath = "D:\My Scripts\config\module-deployment-config.txt"

# Check if config file exists
if (-not (Test-Path $configPath)) {
    Log-Message "WARNING: Module configuration file not found: $configPath. No modules to deploy."
} else {
    try {
        # Read the configuration file
        $modules = Get-Content -Path $configPath

        foreach ($module in $modules) {
            # Skip empty lines
            if (-not $module.Trim()) { continue }

            # Parse module name, source, and destination paths
            $moduleName, $sourcePath, $destinationPath = $module -split '\|'
            $moduleDir = Split-Path $destinationPath -Parent

            Log-Message "Processing module: $moduleName"

            # Ensure source file exists
            if (-not (Test-Path $sourcePath)) {
                Log-Message "ERROR: Source module file not found: $sourcePath. Skipping module."
                continue
            }

            # Create module directory if it doesn't exist
            if (-not (Test-Path $moduleDir)) {
                New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null
                Log-Message "Created module directory: $moduleDir"
            }

            # Copy the module file
            Copy-Item -Path $sourcePath -Destination $destinationPath -Force
            Log-Message "Successfully deployed $sourcePath to $destinationPath"

            # Set permissions for Users group
            icacls "$destinationPath" /grant "Users:(RX)" | Out-Null
            Log-Message "Set read/execute permissions for Users on $destinationPath"
        }

        Log-Message "Module deployment completed successfully"
    } catch {
        Log-Message "ERROR: Failed to deploy modules: $_"
        # Continue execution despite errors
    }
}

Log-Message "Script execution completed."
