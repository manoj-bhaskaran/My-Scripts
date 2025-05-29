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
    Version: 1.0
#>

param (
    [string]$SourceRepo = "D:\My Scripts",
    [string]$TargetDirectory = "C:\Users\manoj\Documents\Scripts"
)

Write-Host "Starting one-time synchronisation..." -ForegroundColor Cyan
Write-Host "Source: $SourceRepo"
Write-Host "Target: $TargetDirectory"
Write-Host ""

# Ensure paths exist
if (-not (Test-Path $SourceRepo)) {
    Write-Host "ERROR: Source path does not exist." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $TargetDirectory)) {
    Write-Host "Target path does not exist. Creating..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
}

# Perform robocopy with exclusions
Write-Host "Running robocopy (excluding .txt, .log, venv, Handle, and Google Drive JSON)...`n" -ForegroundColor Green

$robocopyCmd = @(
    "$SourceRepo",
    "$TargetDirectory",
    "/E", "/PURGE",
    "/XD", "venv", "Google Drive JSON", "Handle",
    "/XF", "*.txt", "*.log",
    "/R:1", "/W:1",
    "/NFL", "/NDL", "/NP", "/NJH", "/NJS"
)

$exitCode = & robocopy @robocopyCmd

if ($exitCode -le 3) {
    Write-Host "`nSync completed successfully. Robocopy exit code: $exitCode" -ForegroundColor Green
} else {
    Write-Host "`nWARNING: Robocopy reported issues. Exit code: $exitCode" -ForegroundColor Red
    Write-Host "Refer to: https://ss64.com/nt/robocopy-exit.html for exit code meanings."
}

Write-Host "`nOne-time sync finished."
