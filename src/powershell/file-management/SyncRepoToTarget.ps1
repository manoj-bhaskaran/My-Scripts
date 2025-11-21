<#
.SYNOPSIS
    One-time synchronisation script to mirror a Git repository to a staging/deployment directory.

.DESCRIPTION
    This script copies all files and subdirectories from the source Git repository to the target directory,
    preserving directory structure. It avoids deleting or overwriting specific excluded files and folders,
    such as log files, text files, and virtual environments.

.PARAMETER SourceRepo
    The root path of the source Git repository.

.PARAMETER TargetDirectory
    The destination path where files should be mirrored.

.NOTES
    Author: Manoj Bhaskaran
    Version: 2.0.0

    CHANGELOG
    ## 2.0.0 - 2025-11-16
    ### Changed
    - Migrated to PowerShellLoggingFramework.psm1 for standardized logging
    - Replaced Write-Host calls with Write-LogInfo and Write-LogError
#>

param (
    [string]$SourceRepo = "D:\My Scripts",
    [string]$TargetDirectory = "C:\Users\manoj\Documents\Scripts"
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

Write-LogInfo "Starting one-time synchronisation..."
Write-LogInfo "Source: $SourceRepo"
Write-LogInfo "Target: $TargetDirectory"

# Ensure paths exist
if (-not (Test-Path $SourceRepo)) {
    Write-LogError "ERROR: Source path does not exist."
    exit 1
}
if (-not (Test-Path $TargetDirectory)) {
    Write-LogWarning "Target path does not exist. Creating..."
    New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
}

# Perform robocopy with exclusions
Write-LogInfo "Running robocopy (excluding .txt, .log, venv, Handle, and Google Drive JSON)..."

$robocopyCmd = @(
    "$SourceRepo",
    "$TargetDirectory",
    "/E", "/PURGE",
    "/XD", "venv", "Google Drive JSON", "Handle", "temp",
    "/XF", "*.txt", "*.log",
    "/R:1", "/W:1",
    "/NFL", "/NDL", "/NP", "/NJH", "/NJS"
)

$exitCode = & robocopy @robocopyCmd

if ($exitCode -le 3) {
    Write-LogInfo "Sync completed successfully. Robocopy exit code: $exitCode"
}
else {
    Write-LogError "WARNING: Robocopy reported issues. Exit code: $exitCode"
    Write-LogError "Refer to: https://ss64.com/nt/robocopy-exit.html for exit code meanings."
}

Write-LogInfo "One-time sync finished."
