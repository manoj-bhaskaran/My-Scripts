# =====================================================================
# Profile-Helpers.ps1
#
# Dot-sourced by $PROFILE. Requires these variables to be set BEFORE
# dot-sourcing:
#   $RepoRoot   - root of the repo's src folder
#   $PsRoot     - root of the PowerShell subtree within the repo
#   $CacheDir   - local cache directory (e.g. under $env:LOCALAPPDATA)
#
# Goals:
#   1) All repo .ps1 scripts under $PsRoot are runnable from anywhere
#      by typing the script name (no path).
#      Implementation: PSReadLine Enter-key rewrite to:
#         & '<full-path-to-script.ps1>' <original-args>
#      Startup stays fast: NO proxy functions created.
#
#   2) Repo modules are NOT imported at startup (fast startup).
#      They are imported lazily ON FIRST repo-script invocation (once
#      per session), restricted to: ...\src\powershell\modules\...
#
# Usage:
#   - Run once after adding/renaming scripts/modules:
#       Update-RepoIndex
#   - Scripts:
#       FileDistributor -SourceFolder ... -TargetFolder ...
#   - Modules:
#       (import happens automatically the first time you run a repo script)
#
# =====================================================================

$ScriptCache = Join-Path $CacheDir "script_index.json"
$ModuleCache = Join-Path $CacheDir "module_index.json"
New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null

# ------------------------------
# Index builder (run manually)
# ------------------------------
function Update-RepoIndex {
    [CmdletBinding()]
    param(
        [string]$Root = $PsRoot
    )
    if (-not (Test-Path $Root)) {
        throw ("Root path does not exist: {0}" -f $Root)
    }
    $excludeDirs = @("node_modules", ".git", ".venv", "venv", "__pycache__", "dist", "build", ".next", ".idea", ".vscode")
    $files =
        Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in ".ps1", ".psm1", ".psd1" -and
            ($excludeDirs -notcontains $_.Directory.Name)
        }
    # Script index: all .ps1 files, deduped by name (keep newest)
    $scripts =
        $files |
        Where-Object Extension -eq ".ps1" |
        ForEach-Object {
            [PSCustomObject]@{
                Name = [IO.Path]::GetFileNameWithoutExtension($_.Name)
                Path = $_.FullName
            }
        } |
        Group-Object Name |
        ForEach-Object {
            $_.Group |
            Sort-Object { (Get-Item $_.Path).LastWriteTimeUtc } -Descending |
            Select-Object -First 1
        }
    $scripts | ConvertTo-Json -Depth 4 | Set-Content -Path $ScriptCache -Encoding UTF8
    # Refresh in-memory map so the current session sees the new index immediately
    $global:RepoScripts = @{}
    foreach ($e in $scripts) {
        if ($null -ne $e.Name -and $null -ne $e.Path) {
            $global:RepoScripts[$e.Name] = $e.Path
        }
    }
    # Module index: all .psm1/.psd1
    $modules =
        $files |
        Where-Object { $_.Extension -in ".psd1", ".psm1" } |
        Sort-Object FullName -Unique |
        ForEach-Object { $_.FullName }
    $modules | ConvertTo-Json -Depth 2 | Set-Content -Path $ModuleCache -Encoding UTF8
    Write-Host ("Repo index updated. Scripts: {0}, Modules: {1}" -f $scripts.Count, $modules.Count)
    Write-Host ("Script cache: {0}" -f $ScriptCache)
    Write-Host ("Module cache: {0}" -f $ModuleCache)
}

# ------------------------------
# Load cached script index (fast)
# ------------------------------
$global:RepoScripts = @{}
if (Test-Path $ScriptCache) {
    try {
        $idx = (Get-Content $ScriptCache -Raw) | ConvertFrom-Json
        foreach ($e in $idx) {
            if ($null -ne $e.Name -and $null -ne $e.Path) {
                $global:RepoScripts[$e.Name] = $e.Path
            }
        }
    } catch {
        $global:RepoScripts = @{}
    }
}

# Generic runner (always works; does not depend on PSReadLine)
function Run-RepoScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(ValueFromRemainingArguments = $true)][object[]]$Args
    )
    $key = [IO.Path]::GetFileNameWithoutExtension($Name)
    if (-not $global:RepoScripts.ContainsKey($key)) {
        throw ("Repo script not found under {0}: {1}" -f $PsRoot, $Name)
    }
    & $global:RepoScripts[$key] @Args
}

# Tab completion for Run-RepoScript -Name
Register-ArgumentCompleter -CommandName Run-RepoScript -ParameterName Name -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    $global:RepoScripts.Keys |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

# ------------------------------
# Lazy module import (once per session)
# ------------------------------
$global:RepoModulesLoaded = $false
function Ensure-RepoModulesLoaded {
    if ($global:RepoModulesLoaded) { return }
    if (-not (Test-Path $ModuleCache)) {
        throw ("Module cache not found at '{0}'. Run Update-RepoIndex first." -f $ModuleCache)
    }
    $moduleFiles = (Get-Content $ModuleCache -Raw) | ConvertFrom-Json |
                   Where-Object { $_ -like "*\powershell\modules\*" }
    foreach ($mf in $moduleFiles) {
        try {
            Import-Module $mf -Force -Global -ErrorAction Stop
        } catch {
            # Uncomment for diagnostics:
            # Write-Warning ("Module import failed: {0} - {1}" -f $mf, $_.Exception.Message)
        }
    }
    $global:RepoModulesLoaded = $true
}

# ------------------------------
# PSReadLine Enter handler: expand repo script names to full path
# ------------------------------
if (Get-Module -ListAvailable -Name PSReadLine) {
    $global:__RepoKeyHandlerBusy = $false
    Set-PSReadLineKeyHandler -Chord Enter -BriefDescription "RepoScriptExpand" -ScriptBlock {
        param($key, $arg)
        if ($global:__RepoKeyHandlerBusy) {
            [Microsoft.PowerShell.PSConsoleReadLine]::ValidateAndAcceptLine()
            return
        }
        $global:__RepoKeyHandlerBusy = $true
        try {
            $line = $null
            $cursor = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $m = [regex]::Match($line, '^\s*(\S+)(.*)$')
                if ($m.Success) {
                    $cmd  = $m.Groups[1].Value
                    $rest = $m.Groups[2].Value
                    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
                        if ($global:RepoScripts -and $global:RepoScripts.ContainsKey($cmd)) {
                            Ensure-RepoModulesLoaded
                            $path = $global:RepoScripts[$cmd]
                            $newLine = "& '$path'$rest"
                            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $newLine)
                        }
                    }
                }
            }
        } finally {
            $global:__RepoKeyHandlerBusy = $false
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::ValidateAndAcceptLine()
    }
}

# ------------------------------
# Convenience status (optional)
# ------------------------------
function Show-RepoProfileStatus {
    [CmdletBinding()]
    param()
    [PSCustomObject]@{
        RepoRoot                 = $RepoRoot
        PsRoot                   = $PsRoot
        ScriptCache              = $ScriptCache
        ModuleCache              = $ModuleCache
        ScriptsLoaded            = $global:RepoScripts.Count
        ScriptCacheExists        = (Test-Path $ScriptCache)
        ModuleCacheExists        = (Test-Path $ModuleCache)
        ModulesLoadedThisSession = $global:RepoModulesLoaded
    }
}
