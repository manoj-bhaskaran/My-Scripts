<#
.SYNOPSIS
    Post-merge Git hook PowerShell script to mirror merged files to a staging directory
    and deploy PowerShell modules per config.

.DESCRIPTION
    After a merge, this script:
      - Mirrors changed files into a staging folder (EXACT repo structure, no version folders)
      - Deploys modified PowerShell modules listed in config\module-deployment-config.txt
        into versioned target folders and writes manifests (RootModule only; FunctionsToExport omitted).

    Targets mapping:
      * System -> C:\Program Files\WindowsPowerShell\Modules\User\<ModuleName>\<Version>\
      * User   -> %USERPROFILE%\Documents\WindowsPowerShell\Modules\<ModuleName>\<Version>\
      * Alt:<ABS_PATH> -> <ABS_PATH>\<ModuleName>\<Version>\

    Config format (pipe-separated; Author/Description optional):
      ModuleName | RelativePathFromRepoRoot | Targets | [Author] | [Description]

.PARAMETER Verbose
    Enable verbose console output.

.NOTES
    Author: Manoj Bhaskaran
    Version: 3.1.0
    Last Updated: 2025-11-22
    CHANGELOG:
        3.1.0 - Fixed logging initialization order and config loading sequence
        3.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        2.6   - Previous version with custom Write-Message function
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

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

# Check if deployment is enabled (before initializing logging)
if ($localConfig.enabled -eq $false) {
    Write-Warning "Deployment disabled in local config. Exiting."
    exit 0
}

# STAGING MIRROR: exact repo structure (no versioned folders, no manifests here)
$script:DestinationFolder = $localConfig.stagingMirror
if (-not $script:DestinationFolder) {
    Write-Error "stagingMirror not configured in $localConfigPath"
    exit 1
}

# Create logs subdirectory
$logsDir = Join-Path $script:DestinationFolder "logs"
if (-not (Test-Path -LiteralPath $logsDir)) {
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
}

# Import logging framework AFTER determining log directory
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger with the correct log directory
Initialize-Logger -resolvedLogDir $logsDir -ScriptName "post-merge-my-scripts" -LogLevel 20

# Deployment configuration lives under repo\config\modules\
$configPath = Join-Path $script:RepoPath "config\modules\deployment.txt"

# ==============================================================================================
# Logging & helpers
# ==============================================================================================

function Write-Message {
    param(
        [string]$Message,
        [string]$Source = "post-merge",
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

function Test-Ignored {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $res = git -C $script:RepoPath check-ignore "$RelativePath" 2>$null
    return -not [string]::IsNullOrWhiteSpace($res)
}

function Get-HeaderVersion {
    param([Parameter(Mandatory = $true)][string]$Path)
    $top = (Get-Content -Path $Path -TotalCount 120 -ErrorAction Stop) -join "`n"
    $m = [regex]::Match($top, '(?im)^\s*Version\s*:\s*(\d+(?:\.\d+){1,3})\s*$')
    if (-not $m.Success) { throw ("No 'Version: x.y.z' header found in {0}" -f $Path) }
    $raw = $m.Groups[1].Value
    if (($raw.Split('.')).Count -lt 3) { $raw = $raw + '.0' }  # x.y -> x.y.0
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
    try { (Resolve-Path -LiteralPath $p -ErrorAction Stop).ProviderPath } catch { $p }
}

function New-OrUpdateManifest {
    <#
    .NOTES
        FunctionsToExport omitted → defaults to '*' (respects Export-ModuleMember).
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

function Test-TextSafe {
    param([string]$Text, [int]$Max = 200)
    if ($null -eq $Text) { return $false }
    if ($Text.Length -gt $Max) { return $false }
    if ($Text -match '[\u0000-\u001F\|]') { return $false } # control chars or pipe forbidden
    return $true
}

# ==============================================================================================
# Deployment (with strong config validation + optional Author/Description from config)
# ==============================================================================================

function Deploy-ModuleFromConfig {
    <#
    .SYNOPSIS
        Deploys modules listed in the config file to configured targets with diagnostics.
    .NOTES
        Config line format:
          ModuleName | RelativePathFromRepoRoot | Targets | [Author] | [Description]
        Optional fields fallback to:
          Author=$env:USERNAME, Description="PowerShell module"
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

    $repoRootResolved = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoPath -ErrorAction Stop).ProviderPath)
    $allowedFixedTargets = @('System', 'User')
    $lines = @(Get-Content -Path $ConfigPath -ErrorAction Stop)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $raw = $lines[$i]
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }

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
        $authorRaw = if ($parts.Count -ge 4) { $parts[3] } else { $null }
        $descriptionRaw = if ($parts.Count -ge 5) { $parts[4] } else { $null }

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

        # Build and validate module path
        $absPath = Join-Path $RepoPath $relPath
        try { $resolved = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $absPath -ErrorAction Stop).ProviderPath) }
        catch { $resolved = [System.IO.Path]::GetFullPath($absPath) }

        # Ensure the resolved path sits inside the repo root (no traversal outside)
        if (-not $resolved.StartsWith($repoRootResolved, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Message ("Config error line {0}: RelativePath escapes repo root -> {1}" -f ($i + 1), $relPath)
            continue
        }

        if (-not (Test-Path -LiteralPath $resolved)) {
            Write-Message ("Module path not found (line {0}): {1}" -f ($i + 1), $absPath)
            continue
        }

        # Must be a .psm1 file and a leaf
        if ([IO.Path]::GetExtension($resolved) -ne '.psm1') {
            Write-Message ("Config error line {0}: RelativePath must point to a .psm1 file -> {1}" -f ($i + 1), $relPath)
            continue
        }
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            Write-Message ("Config error line {0}: RelativePath is not a file -> {1}" -f ($i + 1), $relPath)
            continue
        }

        # Sanitize author/description
        $author = if ($authorRaw) { $authorRaw.Trim() }      else { $env:USERNAME }
        $description = if ($descriptionRaw) { $descriptionRaw.Trim() } else { "PowerShell module" }
        if (-not (Test-TextSafe $author)) { $author = $env:USERNAME }
        if (-not (Test-TextSafe $description)) { $description = "PowerShell module" }

        # Sanity check the module (syntax + presence of functions or Export-ModuleMember)
        if (-not (Test-ModuleSanity -Path $resolved)) {
            Write-Message ("Skipping deploy for {0} due to failed sanity check." -f $moduleName)
            continue
        }

        # Parse module version from header
        try { $ver = Get-HeaderVersion -Path $resolved }
        catch { Write-Message ("Cannot parse version for {0}: {1}" -f $moduleName, $_); continue }

        # --- Targets: System/User/Alt ---
        foreach ($t in $targets) {
            if ($t -ieq 'System') { $baseRoot = "C:\Program Files\WindowsPowerShell\Modules\User" }
            elseif ($t -ieq 'User') { $baseRoot = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules" }
            elseif ($t -like 'Alt:*') {
                try { $baseRoot = Get-SafeAbsolutePath ($t.Substring(4)) }
                catch { Write-Message ("Alt path error (line {0}): {1}" -f ($i + 1), $_); continue }
            }
            else { Write-Message ("Unknown target '{0}' (line {1})" -f $t, ($i + 1)); continue }

            $moduleRoot = Join-Path $baseRoot $moduleName
            $destVersionDir = Join-Path $moduleRoot $ver.ToString()
            New-DirectoryIfMissing $destVersionDir

            $destPsm1 = Join-Path $destVersionDir "$moduleName.psm1"
            $destPsd1 = Join-Path $destVersionDir "$moduleName.psd1"

            try {
                Copy-Item -LiteralPath $resolved -Destination $destPsm1 -Force -ErrorAction Stop
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

Write-Message "post-merge script execution started."

if ($script:IsVerbose) {
    Write-Host "Verbose mode enabled"
    Write-Host ("Repository Path: {0}" -f $script:RepoPath)
    Write-Host ("Destination Folder (staging mirror): {0}" -f $script:DestinationFolder)
    Write-Host ("Config Path: {0}" -f $configPath)
}

# Abort if unmerged paths exist (safety)
$unmerged = git -C $script:RepoPath ls-files -u
if ($unmerged) {
    Write-Message "Unmerged paths detected; aborting deployment step."
    return
}

# Determine changed files from merge using merge-base for accuracy; fallbacks included
$mergeBase = $null
try { $mergeBase = git -C $script:RepoPath merge-base ORIG_HEAD HEAD 2>$null } catch {}

if ($mergeBase) {
    $modifiedFiles = git -C $script:RepoPath diff --name-only --diff-filter=ACMRT $mergeBase HEAD
    $deletedFiles = git -C $script:RepoPath diff --name-only --diff-filter=D     $mergeBase HEAD
}
else {
    # Fallback to ORIG_HEAD..HEAD, then HEAD~1..HEAD
    $modifiedFiles = git -C $script:RepoPath diff --name-only --diff-filter=ACMRT ORIG_HEAD HEAD 2>$null
    $deletedFiles = git -C $script:RepoPath diff --name-only --diff-filter=D     ORIG_HEAD HEAD 2>$null
    if (-not $modifiedFiles) {
        $modifiedFiles = git -C $script:RepoPath diff --name-only --diff-filter=ACMRT HEAD~1 HEAD
        $deletedFiles = git -C $script:RepoPath diff --name-only --diff-filter=D     HEAD~1 HEAD
    }
}

if ($script:IsVerbose) {
    Write-Host "Modified Files (merge):" -ForegroundColor Green
    $modifiedFiles | ForEach-Object { Write-Host $_ }
    Write-Host "Deleted Files (merge):" -ForegroundColor Red
    $deletedFiles | ForEach-Object { Write-Host $_ }
}

# 1) STAGING MIRROR: copy modified files preserving EXACT repo structure.
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

# 2) Deploy touched modules based on config\module-deployment-config.txt.
Deploy-ModuleFromConfig -RepoPath $script:RepoPath -ConfigPath $configPath -TouchedRelPaths $modifiedFiles

# 3) Remove deleted files from the DestinationFolder staging mirror.
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

Write-Message "post-merge script execution completed."
