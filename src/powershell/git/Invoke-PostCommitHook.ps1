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
    Version: 3.2.0
    Last Updated: 2026-05-29
    CHANGELOG:
        3.2.0 - Refactored Deploy-ModuleFromConfig into focused helpers to reduce cognitive complexity
        3.1.0 - Fixed logging initialization order and config loading sequence
        3.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        2.5   - Previous version with custom Write-Message function
#>

[CmdletBinding()]
param ()

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
Initialize-Logger -resolvedLogDir $logsDir -ScriptName "post-commit-my-scripts" -LogLevel 20

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

function Test-TextSafe {
    param([string]$Text, [int]$Max = 200)
    if ($null -eq $Text) { return $false }
    if ($Text.Length -gt $Max) { return $false }
    if ($Text -match '[\u0000-\u001F\|]') { return $false } # control chars or pipe forbidden
    return $true
}

function Test-Ignored {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $res = git -C $script:RepoPath check-ignore "$RelativePath" 2>$null
    return -not [string]::IsNullOrWhiteSpace($res)
}

# ==============================================================================================
# Deployment helpers
# ==============================================================================================

function Test-TargetList {
    param(
        [string[]] $Targets,
        [string[]] $AllowedFixedTargets,
        [int]      $LineNumber
    )
    $invalid = @()
    foreach ($t in $Targets) {
        if ($t -like 'Alt:*') { if (-not $t.Substring(4)) { $invalid += $t } }
        elseif ($AllowedFixedTargets -notcontains $t) { $invalid += $t }
    }
    if ($invalid.Count) {
        Write-Message ("Config error line {0}: invalid target(s): {1}" -f $LineNumber, ($invalid -join ', '))
        return $false
    }
    return $true
}

function Get-ParsedConfigLine {
    <#
    .NOTES
        Config line format (pipe-separated):
          ModuleName | RelativePathFromRepoRoot | Targets | [Author] | [Description]
        Returns a hashtable of parsed fields, or $null if the line is blank, a comment, or invalid.
    #>
    param(
        [string]   $RawLine,
        [int]      $LineNumber,
        [string[]] $AllowedFixedTargets
    )

    $line = $RawLine.Trim()
    if (-not $line -or $line.StartsWith('#')) { return $null }

    if ($line -notmatch '^[^|]+\|[^|]+\|.+$') {
        Write-Message ("Config parse error at line {0}: expected 'Module|RelPath|Targets[|Author][|Description]' -> {1}" -f $LineNumber, $RawLine)
        return $null
    }

    $parts = $line.Split('|')
    if ($parts.Count -lt 3) {
        Write-Message ("Config parse error at line {0}: need at least 3 fields -> {1}" -f $LineNumber, $RawLine)
        return $null
    }

    $moduleName = $parts[0].Trim()
    $relPath    = $parts[1].Trim()
    $targetsCsv = $parts[2].Trim()

    if (-not $moduleName) { Write-Message ("Config error line {0}: empty ModuleName"   -f $LineNumber); return $null }
    if (-not $relPath)    { Write-Message ("Config error line {0}: empty RelativePath" -f $LineNumber); return $null }
    if (-not $targetsCsv) { Write-Message ("Config error line {0}: empty Targets"      -f $LineNumber); return $null }

    $targets = $targetsCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if (-not $targets) { Write-Message ("Config error line {0}: no targets specified" -f $LineNumber); return $null }

    if (-not (Test-TargetList -Targets $targets -AllowedFixedTargets $AllowedFixedTargets -LineNumber $LineNumber)) {
        return $null
    }

    $authorRaw      = if ($parts.Count -ge 4) { $parts[3] } else { $null }
    $descriptionRaw = if ($parts.Count -ge 5) { $parts[4] } else { $null }

    return @{
        ModuleName      = $moduleName
        RelPath         = $relPath
        Targets         = $targets
        AuthorRaw       = $authorRaw
        DescriptionRaw  = $descriptionRaw
    }
}

function Resolve-ModuleSourcePath {
    param(
        [string] $RepoPath,
        [string] $RelPath,
        [string] $RepoRootNormalized,
        [int]    $LineNumber
    )

    $absPath = Join-Path $RepoPath $RelPath
    try   { $resolved = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $absPath -ErrorAction Stop).ProviderPath) }
    catch { $resolved = [System.IO.Path]::GetFullPath($absPath) }

    if (-not $resolved.StartsWith($RepoRootNormalized, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Message ("Config error line {0}: RelativePath escapes repo root -> {1}" -f $LineNumber, $RelPath)
        return $null
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
        Write-Message ("Module path not found (line {0}): {1}" -f $LineNumber, $absPath)
        return $null
    }
    if ([IO.Path]::GetExtension($resolved) -ne '.psm1') {
        Write-Message ("Config error line {0}: RelativePath must point to a .psm1 file -> {1}" -f $LineNumber, $RelPath)
        return $null
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        Write-Message ("Config error line {0}: RelativePath is not a file -> {1}" -f $LineNumber, $RelPath)
        return $null
    }

    return $resolved
}

function Get-TargetBaseRoot {
    param(
        [string] $Target,
        [int]    $LineNumber
    )

    if ($Target -ieq 'System') { return "C:\Program Files\WindowsPowerShell\Modules\User" }
    if ($Target -ieq 'User')   { return (Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules") }
    if ($Target -like 'Alt:*') {
        try   { return Get-SafeAbsolutePath ($Target.Substring(4)) }
        catch { Write-Message ("Alt path error (line {0}): {1}" -f $LineNumber, $_); return $null }
    }

    Write-Message ("Unknown target '{0}' (line {1})" -f $Target, $LineNumber)
    return $null
}

function Invoke-ModuleTargetDeployment {
    param(
        [string]  $BaseRoot,
        [string]  $ModuleName,
        [version] $Version,
        [string]  $SourcePath,
        [string]  $Author,
        [string]  $Description,
        [int]     $LineNumber
    )

    $destVersionDir = Join-Path (Join-Path $BaseRoot $ModuleName) $Version.ToString()
    New-DirectoryIfMissing $destVersionDir

    $destPsm1 = Join-Path $destVersionDir "$ModuleName.psm1"
    $destPsd1 = Join-Path $destVersionDir "$ModuleName.psd1"

    try {
        Copy-Item -LiteralPath $SourcePath -Destination $destPsm1 -Force -ErrorAction Stop
        New-OrUpdateManifest -ManifestPath $destPsd1 -Version $Version -ModuleName $ModuleName `
            -Author $Author -Description $Description
        Write-Message ("Deployed {0} {1} -> {2} (manifest: {3})" -f $ModuleName, $Version, $destVersionDir, $destPsd1)
    }
    catch {
        Write-Message ("Deployment error for {0} -> {1}: {2}" -f $ModuleName, $destVersionDir, $_)
    }
}

function Invoke-SingleModuleDeployment {
    param(
        [hashtable] $Config,
        [string]    $RepoPath,
        [string]    $RepoRootNormalized,
        [int]       $LineNumber,
        [string[]]  $TouchedRelPaths
    )

    if ($TouchedRelPaths -and ($TouchedRelPaths -notcontains $Config.RelPath)) { return }

    $resolved = Resolve-ModuleSourcePath -RepoPath $RepoPath -RelPath $Config.RelPath `
        -RepoRootNormalized $RepoRootNormalized -LineNumber $LineNumber
    if (-not $resolved) { return }

    $author      = if ($Config.AuthorRaw)      { $Config.AuthorRaw.Trim() }      else { $env:USERNAME }
    $description = if ($Config.DescriptionRaw) { $Config.DescriptionRaw.Trim() } else { "PowerShell module" }

    if (-not (Test-TextSafe $author)) {
        Write-Message ("Config line {0}: invalid author field, using fallback for {1}" -f $LineNumber, $Config.ModuleName)
        $author = $env:USERNAME
    }
    if (-not (Test-TextSafe $description)) {
        Write-Message ("Config line {0}: invalid description field, using fallback for {1}" -f $LineNumber, $Config.ModuleName)
        $description = "PowerShell module"
    }

    if (-not (Test-ModuleSanity -Path $resolved)) {
        Write-Message ("Skipping deploy for {0} due to failed sanity check." -f $Config.ModuleName)
        return
    }

    try   { $ver = Get-HeaderVersion -Path $resolved }
    catch { Write-Message ("Cannot parse version for {0}: {1}" -f $Config.ModuleName, $_); return }

    foreach ($t in $Config.Targets) {
        $baseRoot = Get-TargetBaseRoot -Target $t -LineNumber $LineNumber
        if (-not $baseRoot) { continue }
        Invoke-ModuleTargetDeployment -BaseRoot $baseRoot -ModuleName $Config.ModuleName `
            -Version $ver -SourcePath $resolved -Author $author -Description $description `
            -LineNumber $LineNumber
    }
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

    $repoRootNormalized  = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoPath -ErrorAction Stop).ProviderPath)
    $allowedFixedTargets = @('System', 'User')
    $lines               = @(Get-Content -Path $ConfigPath -ErrorAction Stop)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $parsed = Get-ParsedConfigLine -RawLine $lines[$i] -LineNumber ($i + 1) `
            -AllowedFixedTargets $allowedFixedTargets
        if (-not $parsed) { continue }
        Invoke-SingleModuleDeployment -Config $parsed -RepoPath $RepoPath `
            -RepoRootNormalized $repoRootNormalized -LineNumber ($i + 1) `
            -TouchedRelPaths $TouchedRelPaths
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

# 4) Rebuild the repo index only when PowerShell files were structurally
#    changed: added, copied, renamed, or deleted. Plain modifications (M) do
#    not affect the index because the script name and path remain the same.
if ($hasParent) {
    $newOrRenamedPsFiles = @(git -C $script:RepoPath diff --name-only --diff-filter=ACR HEAD~1 HEAD |
            Where-Object { $_ -match '\.(ps1|psm1|psd1)$' })
}
else {
    # First commit — every tracked PS file is brand new.
    $newOrRenamedPsFiles = @($modifiedFiles | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' })
}
$deletedPsFiles = @($deletedFiles | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' })
$hasPsChanges = ($newOrRenamedPsFiles.Count + $deletedPsFiles.Count) -gt 0
if ($hasPsChanges) {
    $indexScript = Join-Path $script:RepoPath "scripts\Update-RepoIndex.ps1"
    if (Test-Path -LiteralPath $indexScript) {
        $indexParams = @{ PsRoot = Join-Path $script:RepoPath "src\powershell" }
        if ($localConfig.PSObject.Properties['cacheDir']) { $indexParams.CacheDir = $localConfig.cacheDir }
        try {
            & $indexScript @indexParams
            Write-Message "Repo index rebuilt successfully."
        }
        catch {
            Write-Message ("Repo index rebuild failed (non-fatal): {0}" -f $_)
        }
    }
}

# 5) Remove deleted files from the DestinationFolder staging mirror.
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
