<#
.SYNOPSIS
    Installs git post-commit and post-merge hooks for automatic deployment.

.DESCRIPTION
    This script installs the git hooks required for automatic file synchronization
    to your staging mirror directory. It creates wrapper scripts in .git/hooks/
    that call the PowerShell implementation scripts.

.NOTES
    Author: Manoj Bhaskaran
    Version: 1.0.0
    Last Updated: 2025-11-22
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Get repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error "Not in a git repository. Please run this script from within the My-Scripts repository."
    exit 1
}

# Convert to Windows path
$repoRoot = $repoRoot -replace '/', '\'

Write-Host "Installing git hooks in: $repoRoot" -ForegroundColor Green
Write-Host ""

# Define hook directory
$hooksDir = Join-Path $repoRoot ".git\hooks"

if (-not (Test-Path $hooksDir)) {
    Write-Error "Hooks directory not found: $hooksDir"
    exit 1
}

# ==========================================
# Post-Commit Hook
# ==========================================
$postCommitPath = Join-Path $hooksDir "post-commit"
$postCommitContent = @'
#!/bin/sh
# Post-commit hook to sync repository changes to staging mirror
# Calls the PowerShell implementation in src/powershell/git/Invoke-PostCommitHook.ps1

# Get the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Path to the PowerShell script (convert to Windows path)
PS_SCRIPT="$REPO_ROOT/src/powershell/git/Invoke-PostCommitHook.ps1"
PS_SCRIPT_WIN=$(echo "$PS_SCRIPT" | sed 's/\//\\/g')

# Check if PowerShell is available (pwsh for cross-platform, or powershell.exe on Windows)
if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN"
elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN"
elif command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN"
else
    echo "PowerShell not found. Skipping post-commit deployment."
    exit 0
fi
'@

Write-Host "Creating post-commit hook..." -ForegroundColor Cyan
Set-Content -Path $postCommitPath -Value $postCommitContent -Encoding UTF8 -NoNewline
Write-Host "  ✓ Created: $postCommitPath" -ForegroundColor Green

# ==========================================
# Post-Merge Hook
# ==========================================
$postMergePath = Join-Path $hooksDir "post-merge"
$postMergeContent = @'
#!/bin/sh
# Post-merge hook to sync merged changes to staging mirror
# Calls the PowerShell implementation in src/powershell/git/Invoke-PostMergeHook.ps1

# Get the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Path to the PowerShell script (convert to Windows path)
PS_SCRIPT="$REPO_ROOT/src/powershell/git/Invoke-PostMergeHook.ps1"
PS_SCRIPT_WIN=$(echo "$PS_SCRIPT" | sed 's/\//\\/g')

# Check if PowerShell is available (pwsh for cross-platform, or powershell.exe on Windows)
if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN"
elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN"
elif command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN"
else
    echo "PowerShell not found. Skipping post-merge deployment."
    exit 0
fi
'@

Write-Host "Creating post-merge hook..." -ForegroundColor Cyan
Set-Content -Path $postMergePath -Value $postMergeContent -Encoding UTF8 -NoNewline
Write-Host "  ✓ Created: $postMergePath" -ForegroundColor Green

Write-Host ""
Write-Host "Git hooks installed successfully!" -ForegroundColor Green
Write-Host ""

# ==========================================
# Check for local config
# ==========================================
$localConfigPath = Join-Path $repoRoot "config\local-deployment-config.json"
$exampleConfigPath = Join-Path $repoRoot "config\local-deployment-config.json.example"

if (-not (Test-Path $localConfigPath)) {
    Write-Host "⚠ Local deployment config not found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To enable automatic deployment, create your local configuration:" -ForegroundColor Yellow
    Write-Host "  1. Copy the example config:" -ForegroundColor White
    Write-Host "     Copy-Item '$exampleConfigPath' '$localConfigPath'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Edit the config with your staging mirror path:" -ForegroundColor White
    Write-Host "     notepad '$localConfigPath'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Set your staging mirror path (e.g., C:\Users\Manoj\Documents\Scripts)" -ForegroundColor White
    Write-Host ""
}
else {
    Write-Host "✓ Local deployment config found: $localConfigPath" -ForegroundColor Green

    # Validate the config
    try {
        $config = Get-Content -Path $localConfigPath -Raw | ConvertFrom-Json

        if (-not $config.stagingMirror) {
            Write-Host "  ⚠ Warning: stagingMirror not set in config" -ForegroundColor Yellow
        }
        elseif (-not (Test-Path $config.stagingMirror)) {
            Write-Host "  ⚠ Warning: Staging mirror directory does not exist: $($config.stagingMirror)" -ForegroundColor Yellow
            Write-Host "    The directory will be created on first deployment." -ForegroundColor Gray
        }
        else {
            Write-Host "  ✓ Staging mirror: $($config.stagingMirror)" -ForegroundColor Green
        }

        if ($config.enabled -eq $false) {
            Write-Host "  ⚠ Deployment is currently DISABLED in config" -ForegroundColor Yellow
            Write-Host "    Set 'enabled: true' to activate automatic deployment." -ForegroundColor Gray
        }
        else {
            Write-Host "  ✓ Deployment enabled" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ⚠ Warning: Could not parse config file: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  • Make a test commit to verify the post-commit hook works"
Write-Host "  • Run 'git pull' to verify the post-merge hook works"
Write-Host "  • Check logs in <stagingMirror>\logs\post-commit-my-scripts_powershell_YYYY-MM-DD.log"
Write-Host ""
