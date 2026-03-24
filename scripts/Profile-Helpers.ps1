<#
.SYNOPSIS
    PowerShell profile helpers: repo-script dispatch, lazy module loading,
    and PSReadLine integration.

.DESCRIPTION
    This file is dot-sourced by $PROFILE. It provides a fast, index-driven
    mechanism for running any .ps1 script in the repo by name alone (no path
    required), with lazy module loading on first use.

    Design goals:
      - Fast startup: no proxy functions created, no modules imported at
        profile load time.
      - Any repo script is invocable by name: the PSReadLine Enter handler
        rewrites "ScriptName [args]" to "& '<full-path>' [args]" before
        execution.
      - Repo modules (under ...\powershell\modules\) are imported once, on
        the first invocation of any repo script in a session.
      - The script/module index is stored as JSON in $CacheDir and is
        rebuilt on demand via Update-RepoIndex.

    Prerequisites - the caller ($PROFILE) must define these variables before
    dot-sourcing this file:
      $RepoRoot   Root of the repo's src folder.
      $PsRoot     Root of the PowerShell subtree within the repo.
      $CacheDir   Writable local directory used to store the JSON cache files.

.NOTES
    Version : 1.0.0
    Requires: PowerShell 5.1+; PSReadLine (optional, for Enter-key expansion)

    Workflow:
      1. Run Update-RepoIndex once after adding, removing, or renaming
         scripts or modules.
      2. From that point forward, type a repo script name at any prompt and
         press Enter — the handler expands it to the full path automatically.
      3. Modules are imported automatically on the first repo-script call
         each session; subsequent calls reuse the already-imported modules.

.EXAMPLE
    # In $PROFILE:
    $RepoRoot = "<path-to-repo>\src"
    $PsRoot   = "<path-to-repo>\src\powershell"
    $CacheDir = Join-Path $env:LOCALAPPDATA "MyScripts"
    . "<path-to-repo>\scripts\Profile-Helpers.ps1"

.EXAMPLE
    # Rebuild the index after adding a new script:
    Update-RepoIndex

.EXAMPLE
    # Check what the profile helpers currently see:
    Show-RepoProfileStatus

.EXAMPLE
    # Run a repo script explicitly (bypasses PSReadLine expansion):
    Run-RepoScript -Name FileDistributor -SourceFolder C:\src -TargetFolder C:\dst
#>

# Script version — increment when behaviour changes.
$ProfileHelpersVersion = '1.0.0'

# -------------------------------------------------------------------------
# Cache file paths (derived from $CacheDir set by the caller)
# -------------------------------------------------------------------------

# JSON file mapping script base-names to their full paths on disk.
$ScriptCache = Join-Path $CacheDir "script_index.json"

# JSON file listing full paths of all .psm1/.psd1 module files in the repo.
$ModuleCache = Join-Path $CacheDir "module_index.json"

# Ensure the cache directory exists; suppress output.
New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null

# -------------------------------------------------------------------------
# Update-RepoIndex
# Scans $PsRoot for .ps1/.psm1/.psd1 files and writes two JSON cache files:
#   - script_index.json  { Name, Path } records for every .ps1 found
#   - module_index.json  full paths of every .psm1/.psd1 found
# Also refreshes $global:RepoScripts in the running session immediately.
# Run this once after adding, renaming, or removing scripts or modules.
# -------------------------------------------------------------------------
function Update-RepoIndex {
<#
.SYNOPSIS
    Rebuilds the repo script and module index cache files.

.DESCRIPTION
    Walks the PowerShell source tree ($PsRoot by default) and writes two
    JSON cache files used at profile load time and for lazy module imports.
    Common tool/build directories are excluded from the scan.

    After writing the cache files, the in-memory hashtable $global:RepoScripts
    is refreshed so the current session immediately reflects any changes —
    no profile reload required.

.PARAMETER Root
    The directory to scan. Defaults to $PsRoot (set in $PROFILE).
    Override for testing or for non-standard layouts.

.EXAMPLE
    Update-RepoIndex
    # Scans the default $PsRoot and reports counts on completion.

.EXAMPLE
    Update-RepoIndex -Root "D:\OtherRepo\src\powershell"
    # Scans an alternative root.
#>
    [CmdletBinding()]
    param(
        [string]$Root = $PsRoot
    )

    if (-not (Test-Path $Root)) {
        throw ("Root path does not exist: {0}" -f $Root)
    }

    # Directories that are never meaningful for PowerShell scripts; skip them
    # to keep the scan fast and avoid false positives from vendored tooling.
    $excludeDirs = @(
        'node_modules', '.git', '.venv', 'venv', '__pycache__',
        'dist', 'build', '.next', '.idea', '.vscode'
    )

    # Single recursive pass — collect all PowerShell-relevant file types.
    # Split the full path into segments and reject any file whose path contains
    # an excluded directory at *any* depth, not just the immediate parent.
    $files =
        Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in '.ps1', '.psm1', '.psd1' -and
            -not ($_.FullName.Split([IO.Path]::DirectorySeparatorChar) |
                  Where-Object { $excludeDirs -contains $_ })
        }

    # Build the script index from .ps1 files.
    # When the same base-name appears more than once (e.g. during a rename),
    # keep only the most recently modified copy to avoid ambiguity.
    $scripts =
        $files |
        Where-Object Extension -eq '.ps1' |
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

    # Persist the script index to disk.
    $scripts | ConvertTo-Json -Depth 4 | Set-Content -Path $ScriptCache -Encoding UTF8

    # Refresh the in-memory map immediately so the current session sees the
    # updated index without requiring a profile reload.
    $global:RepoScripts = @{}
    foreach ($e in $scripts) {
        if ($null -ne $e.Name -and $null -ne $e.Path) {
            $global:RepoScripts[$e.Name] = $e.Path
        }
    }

    # Build the module index from .psm1 and .psd1 files.
    $modules =
        $files |
        Where-Object { $_.Extension -in '.psd1', '.psm1' } |
        Sort-Object FullName -Unique |
        ForEach-Object { $_.FullName }

    # Persist the module index to disk.
    $modules | ConvertTo-Json -Depth 2 | Set-Content -Path $ModuleCache -Encoding UTF8

    Write-Host ("Repo index updated. Scripts: {0}, Modules: {1}" -f $scripts.Count, $modules.Count)
    Write-Host ("Script cache : {0}" -f $ScriptCache)
    Write-Host ("Module cache : {0}" -f $ModuleCache)
}

# -------------------------------------------------------------------------
# Startup: populate $global:RepoScripts from the cached JSON.
# This runs once at dot-source time (i.e. at profile load). It is
# intentionally lightweight — no filesystem scan, just a JSON parse.
# -------------------------------------------------------------------------
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
        # Cache is corrupt or unreadable; start with an empty map.
        # Run Update-RepoIndex to rebuild.
        $global:RepoScripts = @{}
    }
}

# -------------------------------------------------------------------------
# Run-RepoScript
# Explicit fallback runner — invokes a repo script by name without relying
# on PSReadLine. Useful in non-interactive contexts (scripts, CI) or when
# the Enter-key handler is not active.
# -------------------------------------------------------------------------
function Run-RepoScript {
<#
.SYNOPSIS
    Runs a repo script by name, passing through any additional arguments.

.DESCRIPTION
    Looks up the script name in $global:RepoScripts and invokes it with
    splatted arguments. Does not depend on PSReadLine.

    Use this when calling a repo script from another script, or when you
    prefer explicit invocation over the Enter-key expansion.

.PARAMETER Name
    Base name of the script (with or without the .ps1 extension).

.PARAMETER Args
    Any additional arguments to forward to the target script.

.EXAMPLE
    Run-RepoScript -Name FileDistributor -SourceFolder C:\src -TargetFolder C:\dst

.EXAMPLE
    Run-RepoScript FileDistributor -SourceFolder C:\src -TargetFolder C:\dst
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(ValueFromRemainingArguments = $true)][object[]]$Args
    )

    $key = [IO.Path]::GetFileNameWithoutExtension($Name)
    if (-not $global:RepoScripts.ContainsKey($key)) {
        throw ("Repo script not found under {0}: {1}" -f $PsRoot, $Name)
    }
    # Ensure repo modules are loaded before invoking the script. This mirrors
    # what the PSReadLine Enter handler does, so that Run-RepoScript works
    # correctly in non-interactive shells and hosts where the handler is absent.
    Ensure-RepoModulesLoaded
    & $global:RepoScripts[$key] @Args
}

# Tab-completion for Run-RepoScript -Name: offers all indexed script names.
Register-ArgumentCompleter -CommandName Run-RepoScript -ParameterName Name -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    $global:RepoScripts.Keys |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

# -------------------------------------------------------------------------
# Ensure-RepoModulesLoaded
# Imports all repo modules (those under ...\powershell\modules\) exactly
# once per session. Called automatically by the PSReadLine Enter handler
# before the first repo-script invocation; can also be called manually.
# -------------------------------------------------------------------------
$global:RepoModulesLoaded = $false
function Ensure-RepoModulesLoaded {
<#
.SYNOPSIS
    Imports all repo modules if they have not yet been loaded this session.

.DESCRIPTION
    Reads the module index (module_index.json) and imports every .psm1/.psd1
    whose path contains "\powershell\modules\". Subsequent calls are no-ops
    because the result is cached in $global:RepoModulesLoaded.

    Called automatically by the PSReadLine Enter handler before the first
    repo-script invocation each session. You can also call it manually to
    pre-load modules without running a script.

.EXAMPLE
    Ensure-RepoModulesLoaded
    # Imports all repo modules; does nothing if already loaded this session.
#>
    if ($global:RepoModulesLoaded) { return }

    if (-not (Test-Path $ModuleCache)) {
        throw ("Module cache not found at '{0}'. Run Update-RepoIndex first." -f $ModuleCache)
    }

    # Filter to only the modules that live under the designated modules folder;
    # avoids accidentally importing test fixtures or vendored .psm1 files.
    $moduleFiles =
        (Get-Content $ModuleCache -Raw) | ConvertFrom-Json |
        Where-Object { $_ -like '*\powershell\modules\*' }

    foreach ($mf in $moduleFiles) {
        try {
            Import-Module $mf -Force -Global -ErrorAction Stop
        } catch {
            # Import failures are silently swallowed to keep the session
            # usable. Uncomment the line below to diagnose problem modules:
            # Write-Warning ("Module import failed: {0} — {1}" -f $mf, $_.Exception.Message)
        }
    }

    $global:RepoModulesLoaded = $true
}

# -------------------------------------------------------------------------
# PSReadLine Enter handler
# Intercepts the Enter key. When the first token on the line matches a repo
# script name (and is not already a known command), the line is rewritten to
# an explicit invocation before execution:
#   ScriptName [args]  →  & '<full-path-to-script.ps1>' [args]
# Modules are loaded lazily on the first such expansion each session.
# A re-entrancy guard prevents recursive handler invocation.
# -------------------------------------------------------------------------
if (Get-Module -ListAvailable -Name PSReadLine) {

    # Guard flag: prevents the handler from invoking itself recursively.
    $global:__RepoKeyHandlerBusy = $false

    Set-PSReadLineKeyHandler -Chord Enter -BriefDescription 'RepoScriptExpand' -ScriptBlock {
        param($key, $arg)

        # If a previous invocation of this handler is still on the call stack,
        # fall through to the default ValidateAndAcceptLine behaviour.
        if ($global:__RepoKeyHandlerBusy) {
            [Microsoft.PowerShell.PSConsoleReadLine]::ValidateAndAcceptLine()
            return
        }

        $global:__RepoKeyHandlerBusy = $true
        try {
            $line   = $null
            $cursor = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

            if (-not [string]::IsNullOrWhiteSpace($line)) {
                # Split the buffer into the leading command token and the rest.
                $m = [regex]::Match($line, '^\s*(\S+)(.*)$')
                if ($m.Success) {
                    $cmd  = $m.Groups[1].Value
                    $rest = $m.Groups[2].Value

                    # Only expand if the token is not already a known command
                    # (native binary, function, alias, cmdlet, etc.).
                    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {

                        if ($global:RepoScripts -and $global:RepoScripts.ContainsKey($cmd)) {
                            # Ensure modules are available before the script runs.
                            Ensure-RepoModulesLoaded

                            # Rewrite the buffer to the explicit full-path form.
                            $path    = $global:RepoScripts[$cmd]
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

# -------------------------------------------------------------------------
# Show-RepoProfileStatus
# Quick diagnostic: shows the current configuration and runtime state of
# the profile helpers. Useful after a fresh profile load or index rebuild.
# -------------------------------------------------------------------------
function Show-RepoProfileStatus {
<#
.SYNOPSIS
    Displays the current state of the repo profile helpers.

.DESCRIPTION
    Returns a single object summarising the configured paths, cache file
    locations, how many scripts are in the in-memory index, whether the
    cache files exist on disk, and whether modules have been loaded this
    session.

.EXAMPLE
    Show-RepoProfileStatus

    RepoRoot                 : <repo-src-root>
    PsRoot                   : <repo-powershell-root>
    ScriptCache              : <path>\script_index.json
    ModuleCache              : <path>\module_index.json
    ScriptsLoaded            : 12
    ScriptCacheExists        : True
    ModuleCacheExists        : True
    ModulesLoadedThisSession : False
#>
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        Version                  = $ProfileHelpersVersion
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
