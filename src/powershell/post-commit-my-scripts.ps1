<#
.SYNOPSIS
    Post-commit Git hook PowerShell script to copy committed files to a staging directory and update module manifests.

.DESCRIPTION
    This script is invoked by a Git post-commit hook. It processes modified and deleted files from the latest commit, copies them to a destination folder, and updates module manifests for modified PowerShell modules in versioned directories.

.PARAMETER Verbose
    Switch to enable verbose output to the console for debugging.

.NOTES
    Author: Manoj Bhaskaran
    Version: 1.3
    Last Updated: 2025-08-16
#>

param (
    [switch]$Verbose
)

# Define paths
$repoPath = "D:\My Scripts"
$destinationFolder = "C:\Users\manoj\Documents\Scripts"
$logFile = "C:\Users\manoj\Documents\Scripts\git-post-action.log"

# Function to log messages with timestamps and source identifier
function Write-Message {
    param (
        [string]$message,
        [string]$source = "post-commit"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$source] $message"
    Add-Content -Path $logFile -Value $logEntry
    if ($Verbose) {
        Write-Host $logEntry
    }
}

Write-Message "Script execution started."

if ($Verbose) {
    Write-Host "Verbose mode enabled"
    Write-Host "Repository Path: $repoPath"
    Write-Host "Destination Folder: $destinationFolder"
}

# Get list of modified files in the latest commit (excluding deletions)
$modifiedFiles = git -C $repoPath diff-tree --no-commit-id --name-only -r HEAD --diff-filter=ACMRT

if ($Verbose) {
    Write-Host "Modified Files:" -ForegroundColor Green
    $modifiedFiles | ForEach-Object { Write-Host $_ }
}

# Get list of deleted files in the latest commit
$deletedFiles = git -C $repoPath diff-tree --no-commit-id --name-only -r HEAD --diff-filter=D

if ($Verbose) {
    Write-Host "Deleted Files:" -ForegroundColor Red
    $deletedFiles | ForEach-Object { Write-Host $_ }
}

# Function to check if a file matches any ignored patterns
function Test-Ignored {
    param (
        [string]$relativePath
    )
    $result = git -C $repoPath check-ignore "$relativePath" 2>$null
    return -not [string]::IsNullOrWhiteSpace($result)
}

# Function to validate module content
function Test-ModuleContent {
    param (
        [string]$ModulePath
    )
    try {
        $moduleContent = Get-Content -Path $ModulePath -Raw
        return $moduleContent -match '\[Parameter\(Mandatory=\$true\)]\s*\[string\]\$log_file'
    } catch {
        Write-Message "ERROR: Failed to read module content at ${ModulePath}: $_"
        return $false
    }
}

# Function to update or create module manifest
function Update-ModuleManifest {
    param (
        [string]$ModulePath,
        [string]$DestinationPath
    )
    try {
        $moduleContent = Get-Content -Path $ModulePath -Head 20
        $versionLine = $moduleContent | Where-Object { $_ -match "Version: (\d+\.\d+\.\d+)" }
        $version = if ($versionLine) { $matches[1] } else { "1.0.0" }
        $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ModulePath)
        $versionedDestDir = Join-Path -Path (Split-Path (Split-Path $DestinationPath -Parent) -Parent) -ChildPath $version
        $versionedModulePath = Join-Path -Path $versionedDestDir -ChildPath ([System.IO.Path]::GetFileName($DestinationPath))
        $manifestPath = Join-Path -Path $versionedDestDir -ChildPath "$moduleName.psd1"

        # Validate module content
        if (-not (Test-ModuleContent -ModulePath $ModulePath)) {
            Write-Message "ERROR: Module at $ModulePath does not support log_file parameter, required for version $version"
            return
        }

        Write-Message "Updating manifest for module at $ModulePath (version $version)"

        if (-not (Test-Path $versionedDestDir)) {
            New-Item -Path $versionedDestDir -ItemType Directory -Force | Out-Null
            Write-Message "Created versioned module directory: $versionedDestDir"
        }

        Copy-Item -Path $ModulePath -Destination $versionedModulePath -Force
        Write-Message "Copied module file to $versionedModulePath"

        New-ModuleManifest `
            -Path $manifestPath `
            -ModuleVersion $version `
            -RootModule ([System.IO.Path]::GetFileName($DestinationPath)) `
            -FunctionsToExport @('Backup-PostgresDatabase') `
            -Author "Manoj Bhaskaran" `
            -Description "PowerShell module for backing up PostgreSQL databases" `
            -CompatiblePSEditions @("Desktop", "Core")
        Write-Message "Created/updated manifest at $manifestPath for version $version"
    } catch {
        Write-Message "ERROR: Failed to create/update manifest for ${ModulePath}: $_"
    }
}

# Copy modified files, preserving directory structure
$modifiedFiles | ForEach-Object {
    $relativePath = $_
    $sourceFilePath = Join-Path -Path $repoPath -ChildPath $relativePath

    if ((Test-Path $sourceFilePath) -and !(Test-Ignored $relativePath)) {
        Write-Message "Processing modified file: $sourceFilePath"
        $destinationFilePath = Join-Path -Path $destinationFolder -ChildPath $relativePath
        $destinationDir = Split-Path -Path $destinationFilePath -Parent

        if (-not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        try {
            Copy-Item -Path $sourceFilePath -Destination $destinationFilePath -Force
            Write-Message "Copied file $sourceFilePath to $destinationFilePath"

            # Update manifest if this is a module file
            if ($relativePath -like "*PostgresBackup.psm1") {
                Update-ModuleManifest -ModulePath $sourceFilePath -DestinationPath $destinationFilePath
            }
        } catch {
            Write-Message ("Failed to copy {0}: {1}" -f $sourceFilePath, $_.Exception.Message)
        }
    } else {
        Write-Message "File $sourceFilePath is ignored or does not exist"
    }
}

# Delete files in the destination folder that were deleted in the commit
$deletedFiles | ForEach-Object {
    $destinationFilePath = Join-Path -Path $destinationFolder -ChildPath $_
    Write-Message "Processing deleted file: $destinationFilePath"

    if ((Test-Path $destinationFilePath) -and -not (Test-Ignored $_)) {
        Write-Message "Removing file $destinationFilePath"
        try {
            Remove-Item -Path $destinationFilePath -Recurse -Confirm:$false -Force
            Write-Message "Deleted file $destinationFilePath"
        } catch {
            Write-Message ("Failed to delete {0}: {1}" -f $destinationFilePath, $_.Exception.Message)
        }
    } else {
        Write-Message "File $destinationFilePath is ignored or does not exist in the destination folder"
    }
}

Write-Message "Script execution completed."