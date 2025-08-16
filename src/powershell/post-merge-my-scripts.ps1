<#
.SYNOPSIS
    Post-merge Git hook PowerShell script to pull changes and deploy PowerShell modules to versioned directories.

.DESCRIPTION
    This script pulls the latest changes from the main branch, compares files, and deploys PowerShell modules listed in module-deployment-config.txt to versioned directories based on their version comments.

.PARAMETER localRepoPath
    Path to the local Git repository.
.PARAMETER compareDirectory
    Path to the directory to compare files with.
.PARAMETER targetDirectory
    Path to the directory where newer files will be copied.

.NOTES
    Author: Manoj Bhaskaran
    Version: 1.1
    Last Updated: 2025-08-16
#>

# Define paths
$localRepoPath = "D:\My Scripts"
$compareDirectory = "C:\Users\manoj\Documents\Scripts"
$targetDirectory = "C:\Users\manoj\Documents\Scripts"
$logFile = "C:\Users\manoj\Documents\Scripts\git-post-action.log"

# Function to log messages with timestamps and source identifier
function Write-Log {
    param (
        [string]$message,
        [string]$source = "post-merge"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$source] $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry
}

Write-Log "Script execution started."

# Pull the latest changes from the main branch
Write-Log "Pulling latest changes from the main branch..."
Set-Location -Path $localRepoPath
git pull origin main | ForEach-Object { Write-Log $_ }

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
            Write-Log "New file: $relativePath"
            Copy-Item -Path $_.FullName -Destination $targetFilePath -Force
            Write-Log "Copied new file $relativePath to $target"
        } elseif ((Get-Item -Path $_.FullName).LastWriteTime -gt (Get-Item -Path $compareFilePath).LastWriteTime) {
            Write-Log "Updated file: $relativePath"
            Copy-Item -Path $_.FullName -Destination $targetFilePath -Force
            Write-Log "Copied updated file $relativePath to $target"
        }
    }
}

# Compare and copy newer files
Write-Log "Comparing files and copying newer ones to target directory..."
Compare-And-Copy -source $localRepoPath -destination $compareDirectory -target $targetDirectory

# Function to get module version from .psm1 file
function Get-ModuleVersion {
    param (
        [string]$ModulePath
    )
    try {
        $moduleContent = Get-Content -Path $ModulePath -Head 20
        $versionLine = $moduleContent | Where-Object { $_ -match "Version: (\d+\.\d+\.\d+)" }
        return if ($versionLine) { $matches[1] } else { "1.0.0" }
    } catch {
        Write-Log "ERROR: Failed to read version from ${ModulePath}: $_"
        return "1.0.0"
    }
}

# Deploy PowerShell modules listed in the configuration file
Write-Log "Deploying PowerShell modules from module-deployment-config.txt..."
$configPath = "D:\My Scripts\config\module-deployment-config.txt"

if (-not (Test-Path $configPath)) {
    Write-Log "WARNING: Module configuration file not found: $configPath. No modules to deploy."
} else {
    try {
        $modules = Get-Content -Path $configPath
        foreach ($module in $modules) {
            if (-not $module.Trim()) { continue }
            $moduleName, $sourcePath, $destinationPath = $module -split '\|'
            Write-Log "Processing module: $moduleName"

            if (-not (Test-Path $sourcePath)) {
                Write-Log "ERROR: Source module file not found: $sourcePath. Skipping module."
                continue
            }

            $version = Get-ModuleVersion -ModulePath $sourcePath
            $versionedDestPath = Join-Path -Path (Split-Path $destinationPath -Parent) -ChildPath $version
            $versionedModulePath = Join-Path -Path $versionedDestPath -ChildPath (Split-Path $destinationPath -Leaf)
            $versionedManifestPath = Join-Path -Path $versionedDestPath -ChildPath "$moduleName.psd1"

            if (-not (Test-Path $versionedDestPath)) {
                New-Item -Path $versionedDestPath -ItemType Directory -Force | Out-Null
                Write-Log "Created versioned module directory: $versionedDestPath"
            }

            Copy-Item -Path $sourcePath -Destination $versionedModulePath -Force
            Write-Log "Successfully deployed $sourcePath to $versionedModulePath"

            # Create/update manifest
            New-ModuleManifest `
                -Path $versionedManifestPath `
                -ModuleVersion $version `
                -RootModule (Split-Path $versionedModulePath -Leaf) `
                -FunctionsToExport @('Backup-PostgresDatabase') `
                -Author "Your Name or Team" `
                -Description "PowerShell module for backing up PostgreSQL databases" `
                -CompatiblePSEditions @("Desktop")
            Write-Log "Created/updated manifest at $versionedManifestPath for version $version"

            # Set permissions
            icacls "$versionedDestPath" /grant "Users:(RX)" | Out-Null
            Write-Log "Set read/execute permissions for Users on $versionedDestPath"
        }
        Write-Log "Module deployment completed successfully"
    } catch {
        Write-Log "ERROR: Failed to deploy modules: $_"
    }
}

Write-Log "Script execution completed."