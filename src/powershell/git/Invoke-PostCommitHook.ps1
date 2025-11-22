<#
.SYNOPSIS
    Post-commit Git hook PowerShell script to copy committed files to a staging directory and deploy PowerShell modules.

.DESCRIPTION
    This script is invoked by a Git post-commit hook. It processes modified and deleted files from the latest commit,
    mirrors changed files to a staging directory under Documents (EXACT repo folder structure, no version folders),
    and deploys PowerShell modules (e.g., PostgresBackup) to versioned directories with manifests.
    Deployment targets and module paths are controlled by a configuration file at:
    config\module-deployment-config.txt (relative to the repository root).

    For each module listed in the config and touched by the commit, the script:
      - Parses the module header "Version: x.y.z" (x.y -> x.y.0)
      - Sanity checks the module (no syntax errors; has a function or uses Export-ModuleMember)
      - Deploys to targets:
          * System: C:\Program Files\WindowsPowerShell\Modules\User\<ModuleName>\<version>\
          * User:   %USERPROFILE%\Documents\WindowsPowerShell\Modules\<ModuleName>\<version>\
          * Alt:<ABS_PATH>: <ABS_PATH>\<ModuleName>\<version>\
      - Writes/refreshes a manifest (.psd1) in each TARGET with RootModule only
        (FunctionsToExport is intentionally omitted → defaults to '*').

.PARAMETER Verbose
    Switch to enable verbose console output for debugging.

.NOTES
    Author: Manoj Bhaskaran
    Version: 3.0.1
    Last Updated: 2025-11-21
    CHANGELOG:
        3.0.1 - Fixed placement of import statements to be after the CmdletBinding statement
        3.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        2.5   - Previous version with custom Write-Message function
#>

[CmdletBinding()]
param ()

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName "post-commit-my-scripts" -LogLevel 20

# Initialize early so functions can read it safely
$script:IsVerbose = $false
if ($PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -eq 'Continue') {
    $script:IsVerbose = $true
}

# ==============================================================================================
# Configuration
# ==============================================================================================

# Auto-detect repository root
$script:RepoPath = git rev-parse --show-toplevel 2>$null
if (-not $script:RepoPath) {
    Write-Error "Failed to detect Git repository root. Ensure this script runs inside a Git repo."
    exit 1
}
# Convert to Windows path if needed
$script:RepoPath = $script:RepoPath -replace '/', '\'

# Load local deployment configuration
$localConfigPath = Join-Path $script:RepoPath "config\local-deployment-config.json"
if (-not (Test-Path -LiteralPath $localConfigPath)) {
    Write-Warning "Local deployment config not found: $localConfigPath"
    Write-Warning "Copy config\local-deployment-config.json.example to config\local-deployment-config.json and configure your paths."
    exit 0
}

try {
    $localConfig = Get-Content -Path $localConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
}
catch {
    Write-Error "Failed to parse local deployment config: $localConfigPath - $_"
    exit 1
}

# Check if deployment is enabled
if ($localConfig.enabled -eq $false) {
    Write-Message "Deployment disabled in local config. Exiting."
    exit 0
}

# STAGING MIRROR: exact repo structure (no versioned folders, no manifests here)
$script:DestinationFolder = $localConfig.stagingMirror
if (-not $script:DestinationFolder) {
    Write-Error "stagingMirror not configured in $localConfigPath"
    exit 1
}

# Hook log file (in logs subdirectory)
$logsDir = Join-Path $script:DestinationFolder "logs"
if (-not (Test-Path -LiteralPath $logsDir)) {
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
}
$script:LogFile = Join-Path $logsDir "git-post-action.log"

# Deployment configuration lives under repo\config\modules\
# Format (pipe-separated, one per line; comments start with #):
#   ModuleName | RelativePathFromRepoRoot | Targets
# Targets = comma-separated subset of: System, User, Alt:<ABS_PATH>
# Example:
#   PostgresBackup|PostgresBackup.psm1|System,User
$configPath = Join-Path $script:RepoPath "config\modules\deployment.txt"

# ==============================================================================================
# Logging and Helpers
# ==============================================================================================

Set-StrictMode -Version Latest

function Write-Message {
    param(
        [string]$Message,
        [string]$Source = "post-commit",
        [switch]$ToHost
    )
    Write-LogInfo "$Source - $Message"
    if ($script:IsVerbose -or $ToHost) {
        Write-Host "$Source - $Message"
    }
}

function New-DirectoryIfMissing {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Get-HeaderVersion {
    param([Parameter(Mandatory = $true)][string]$Path)
    $top = (Get-Content -Path $Path -TotalCount 120 -ErrorAction Stop) -join "`n"
    $m = [regex]::Match($top, '(?im)^\s*Version\s*:\s*(\d+(?:\.\d+){1,3})\s*$')
    if (-not $m.Success) { throw ("No 'Version: x.y.z' header found in {0}" -f $Path) }
    $raw = $m.Groups[1].Value
    $parts = $raw.Split('.')
    if ($parts.Count -lt 3) { $raw = $raw + '.0' }  # x.y -> x.y.0
    try { return [version]$raw } catch { throw ("Invalid version '{0}' in {1}" -f $raw, $Path) }
}

function Test-ModuleSanity {
    param([Parameter(Mandatory = $true)][string]$Path)

    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)

    if ($errors -and $errors.Count) {
        Write-Message ("Module parse errors in {0}: {1}" -f $Path, ($errors | ForEach-Object { $_.Message } | Select-Object -First 1))
        return $false
    }

    $hasFn = $ast.
    FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true).
    Count -gt 0

    $hasExport = $ast.
    FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Export-ModuleMember' }, $true).
    Count -gt 0

    if (-not ($hasFn -or $hasExport)) {
        Write-Message ("Module sanity check failed for {0}: no functions and no Export-ModuleMember found" -f $Path)
        return $false
    }
    return $true
}

function Get-SafeAbsolutePath {
    param([Parameter(Mandatory = $true)][string]$PathText)

    if ([string]::IsNullOrWhiteSpace($PathText)) { throw "Alt path is empty" }
    if ($PathText -match '[\*\?]') { throw "Alt path contains wildcards: $PathText" }

    $p = $PathText.Trim('"').Trim()
    if (-not [System.IO.Path]::IsPathRooted($p)) { throw "Alt path must be absolute: $p" }

    try {
        return (Resolve-Path -LiteralPath $p -ErrorAction Stop).ProviderPath
    }
    catch {
        return $p  # Path may not exist yet; return normalized text
    }
}

function New-OrUpdateManifest {
    <#
    .NOTES
        FunctionsToExport intentionally omitted → manifest defaults to '*'
        (respects the module's Export-ModuleMember).
    #>
    param(
        [Parameter(Mandatory = $true)][string]  $ManifestPath,
        [Parameter(Mandatory = $true)][version] $Version,
        [Parameter(Mandatory = $true)][string]  $ModuleName,
        [string] $Description = "PowerShell module",
        [string] $Author = $env:USERNAME
    )

    $manifestParams = @{
        Path                 = $ManifestPath
        ModuleVersion        = $Version
        RootModule           = "$ModuleName.psm1"
        Author               = $Author
        Description          = $Description
        CompatiblePSEditions = @("Desktop", "Core")
        ErrorAction          = 'Stop'
    }

    New-ModuleManifest @manifestParams | Out-Null
}

function Test-Ignored {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $res = git -C $script:RepoPath check-ignore "$RelativePath" 2>$null
    return -not [string]::IsNullOrWhiteSpace($res)
}

# ==============================================================================================
# Deployment (with strong config validation + optional Author/Description from config)
# ==============================================================================================
function Deploy-ModuleFromConfig {
    <#
    .SYNOPSIS
        Deploys modules listed in the config file to configured targets (with detailed validation & diagnostics).
    .PARAMETER RepoPath
        Repository root.
    .PARAMETER ConfigPath
        Path to config\module-deployment-config.txt.
    .PARAMETER TouchedRelPaths
        Optional list of relative paths modified in this commit; if provided, only those modules whose RelativePath matches are deployed.

    .NOTES
        Config line format (pipe-separated):
          ModuleName | RelativePathFromRepoRoot | Targets | [Author] | [Description]
        Fields [Author] and [Description] are optional. If omitted:
          Author      -> $env:USERNAME
          Description -> "PowerShell module"
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [string[]]$TouchedRelPaths
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Message ("Config not found: {0}" -f $ConfigPath)
        return
    }

    $allowedFixedTargets = @('System', 'User')
    $lines = Get-Content -Path $ConfigPath -ErrorAction Stop

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $raw = $lines[$i]
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }

        # At least 3 fields required: Module|RelPath|Targets
        if ($line -notmatch '^[^|]+\|[^|]+\|.+$') {
            Write-Message ("Config parse error at line {0}: expected 'Module|RelPath|Targets[|Author][|Description]' -> {1}" -f ($i + 1), $raw)
            continue
        }

        $parts = $line.Split('|')
        if ($parts.Count -lt 3) {
            Write-Message ("Config parse error at line {0}: need at least 3 fields -> {1}" -f ($i + 1), $raw)
            continue
        }

        $moduleName = $parts[0].Trim()
        $relPath = $parts[1].Trim()
        $targetsCsv = $parts[2].Trim()
        $author = if ($parts.Count -ge 4 -and $parts[3].Trim()) { $parts[3].Trim() } else { $env:USERNAME }
        $description = if ($parts.Count -ge 5 -and $parts[4].Trim()) { $parts[4].Trim() } else { "PowerShell module" }

        if (-not $moduleName) { Write-Message ("Config error line {0}: empty ModuleName" -f ($i + 1)); continue }
        if (-not $relPath) { Write-Message ("Config error line {0}: empty RelativePath" -f ($i + 1)); continue }
        if (-not $targetsCsv) { Write-Message ("Config error line {0}: empty Targets" -f ($i + 1)); continue }

        $targets = $targetsCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        if (-not $targets) { Write-Message ("Config error line {0}: no targets specified" -f ($i + 1)); continue }

        $invalidTargets = @()
        foreach ($t in $targets) {
            if ($t -like 'Alt:*') { if (-not $t.Substring(4)) { $invalidTargets += $t } }
            elseif ($allowedFixedTargets -notcontains $t) { $invalidTargets += $t }
        }
        if ($invalidTargets.Count) {
            Write-Message ("Config error line {0}: invalid target(s): {1}" -f ($i + 1), ($invalidTargets -join ', '))
            continue
        }

        # Only deploy if this module file was touched (when TouchedRelPaths is provided)
        if ($TouchedRelPaths -and ($TouchedRelPaths -notcontains $relPath)) { continue }

        $absPath = Join-Path $RepoPath $relPath
        if (-not (Test-Path -LiteralPath $absPath)) {
            Write-Message ("Module path not found (line {0}): {1}" -f ($i + 1), $absPath)
            continue
        }

        # Sanity check the module (syntax + presence of functions or Export-ModuleMember)
        if (-not (Test-ModuleSanity -Path $absPath)) {
            Write-Message ("Skipping deploy for {0} due to failed sanity check." -f $moduleName)
            continue
        }

        # Parse module version from header
        try {
            $ver = Get-HeaderVersion -Path $absPath
        }
        catch {
            Write-Message ("Cannot parse version for {0}: {1}" -f $moduleName, $_)
            continue
        }

        # --- Targets: System/User/Alt ---
        foreach ($t in $targets) {
            if ($t -ieq 'System') { $baseRoot = "C:\Program Files\WindowsPowerShell\Modules\User" }
            elseif ($t -ieq 'User') { $baseRoot = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules" }
            elseif ($t -like 'Alt:*') {
                try { $baseRoot = Get-SafeAbsolutePath ($t.Substring(4)) }
                catch { Write-Message ("Alt path error (line {0}): {1}" -f ($i + 1), $_); continue }
            }
            else {
                Write-Message ("Unknown target '{0}' (line {1})" -f $t, ($i + 1))
                continue
            }

            $moduleRoot = Join-Path $baseRoot $moduleName
            $destVersionDir = Join-Path $moduleRoot $ver.ToString()
            New-DirectoryIfMissing $destVersionDir

            $destPsm1 = Join-Path $destVersionDir "$moduleName.psm1"
            $destPsd1 = Join-Path $destVersionDir "$moduleName.psd1"

            try {
                Copy-Item -LiteralPath $absPath -Destination $destPsm1 -Force -ErrorAction Stop
                New-OrUpdateManifest `
                    -ManifestPath $destPsd1 `
                    -Version      $ver `
                    -ModuleName   $moduleName `
                    -Author       $author `
                    -Description  $description
                Write-Message ("Deployed {0} {1} -> {2} (manifest: {3})" -f $moduleName, $ver, $destVersionDir, $destPsd1)
            }
            catch {
                Write-Message ("Deployment error for {0} -> {1}: {2}" -f $moduleName, $destVersionDir, $_)
            }
        }
    }
}

# ==============================================================================================
# Execution
# ==============================================================================================

Write-Message "post-commit script execution started."

if ($script:IsVerbose) {
    Write-Host "Verbose mode enabled"
    Write-Host ("Repository Path: {0}" -f $script:RepoPath)
    Write-Host ("Destination Folder (staging mirror): {0}" -f $script:DestinationFolder)
    Write-Host ("Config Path: {0}" -f $configPath)
}

# 1) Compute modified and deleted files (support first commit).
$hasParent = $true
try { git -C $script:RepoPath rev-parse HEAD~1 2>$null | Out-Null } catch { $hasParent = $false }

if ($hasParent) {
    $modifiedFiles = git -C $script:RepoPath diff --name-only --diff-filter=ACMRT HEAD~1 HEAD
    $deletedFiles = git -C $script:RepoPath diff --name-only --diff-filter=D     HEAD~1 HEAD
}
else {
    $modifiedFiles = git -C $script:RepoPath ls-tree -r --name-only HEAD
    $deletedFiles = @()
}

if ($script:IsVerbose) {
    Write-Host "Modified Files:" -ForegroundColor Green
    $modifiedFiles | ForEach-Object { Write-Host $_ }
    Write-Host "Deleted Files:" -ForegroundColor Red
    $deletedFiles | ForEach-Object { Write-Host $_ }
}

# 2) STAGING MIRROR: copy modified files into DestinationFolder preserving EXACT repo structure.
foreach ($rel in $modifiedFiles) {
    $src = Join-Path $script:RepoPath $rel
    if ((Test-Path -LiteralPath $src) -and -not (Test-Ignored $rel)) {
        $dst = Join-Path $script:DestinationFolder $rel
        New-DirectoryIfMissing (Split-Path $dst -Parent)
        try {
            Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
            Write-Message ("Copied file {0} to {1}" -f $src, $dst)
        }
        catch {
            Write-Message ("Failed to copy {0}: {1}" -f $src, $_.Exception.Message)
        }
    }
    else {
        Write-Message ("File skipped (ignored or missing): {0}" -f $src)
    }
}

# 3) Deploy touched modules based on config\module-deployment-config.txt.
Deploy-ModuleFromConfig -RepoPath $script:RepoPath -ConfigPath $configPath -TouchedRelPaths $modifiedFiles

# 4) Remove deleted files from the DestinationFolder staging mirror.
foreach ($rel in $deletedFiles) {
    $dst = Join-Path $script:DestinationFolder $rel
    if (Test-Path -LiteralPath $dst) {
        try {
            Remove-Item -LiteralPath $dst -Recurse -Confirm:$false -Force -ErrorAction Stop
            Write-Message ("Deleted file {0}" -f $dst)
        }
        catch {
            Write-Message ("Failed to delete {0}: {1}" -f $dst, $_.Exception.Message)
        }
    }
    else {
        Write-Message ("File not present in mirror (nothing to delete): {0}" -f $dst)
    }
}

Write-Message "post-commit script execution completed."
