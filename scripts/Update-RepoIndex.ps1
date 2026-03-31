<#
.SYNOPSIS
    Standalone script to rebuild the repo script and module index cache.

.DESCRIPTION
    A self-contained wrapper that scans the PowerShell source tree and writes
    two JSON cache files used by Profile-Helpers.ps1:
      - script_index.json  Maps script base-names to full paths.
      - module_index.json  Lists all .psm1/.psd1 module paths.

    Intended to be called as a post-processing step after any deployment
    (post-commit hook, post-merge hook, Deploy-Modules.ps1, install-modules.sh)
    so that newly added scripts and modules are immediately available without
    a manual Update-RepoIndex call.

.PARAMETER PsRoot
    Root of the PowerShell source tree to scan.
    Defaults to <RepoRoot>\src\powershell.

.PARAMETER CacheDir
    Directory where the JSON cache files are written.
    Defaults to the OS-appropriate standard location:
      Windows : %LOCALAPPDATA%\MyScripts
      Linux/macOS : $HOME/.cache/my-scripts

.EXAMPLE
    .\scripts\Update-RepoIndex.ps1
    Rebuild using defaults (repo's PowerShell tree, standard cache dir).

.EXAMPLE
    .\scripts\Update-RepoIndex.ps1 -PsRoot "D:\Repo\src\powershell" -CacheDir "C:\Cache\MyScripts"
    Rebuild with explicit paths.

.NOTES
    Version: 1.0.0
    Author: Manoj Bhaskaran
#>

[CmdletBinding()]
param(
    [string]$PsRoot,
    [string]$CacheDir
)

$ErrorActionPreference = 'Stop'

# Resolve defaults relative to the repository root (this script lives in /scripts/).
$scriptDir = $PSScriptRoot
$repoRoot = Split-Path -Path $scriptDir -Parent

if (-not $PsRoot) {
    $PsRoot = Join-Path $repoRoot "src" "powershell"
}

if (-not $CacheDir) {
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        $CacheDir = Join-Path $env:LOCALAPPDATA "MyScripts"
    }
    else {
        $CacheDir = Join-Path $HOME ".cache" "my-scripts"
    }
}

# Validate inputs before doing any work.
if (-not (Test-Path $PsRoot)) {
    Write-Error "PsRoot does not exist: $PsRoot"
    exit 1
}

# Set the variables that Profile-Helpers.ps1 reads at dot-source time.
$RepoRoot = Join-Path $repoRoot "src"

# Dot-source Profile-Helpers to bring Update-RepoIndex into scope.
# Running with -NoProfile means PSReadLine is absent, so the Enter-key
# handler block inside Profile-Helpers is silently skipped.
$profileHelpers = Join-Path $scriptDir "Profile-Helpers.ps1"
if (-not (Test-Path $profileHelpers)) {
    Write-Error "Profile-Helpers.ps1 not found at: $profileHelpers"
    exit 1
}

. $profileHelpers

# Call the function, explicitly passing the resolved root so the correct
# tree is scanned regardless of how $PsRoot was set in the caller's scope.
Update-RepoIndex -Root $PsRoot
