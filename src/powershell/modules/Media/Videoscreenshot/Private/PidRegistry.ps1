<#
.NOTES
DEPENDENCIES
  - Add-ContentWithRetry: provides resilient append semantics for text writes.
DESIGN
  - Append-only registry simplifies concurrency and preserves an audit trail.
  - Context carries the registry path to keep helpers stateless and focused.
#>
<#
.SYNOPSIS
Create a per-run PID registry file and attach it to the run context.
.DESCRIPTION
Builds a sidecar text file under SaveFolder (e.g., ".vlc_pids_<RunGuid>.txt")
and stores its path on $Context.PidRegistryPath. The file is (re)created for
each run and a small header is written. Callers should use Register-RunPid and
Unregister-RunPid to append lifecycle records.
.PARAMETER Context
Per-run context object; this function sets .PidRegistryPath.
.PARAMETER SaveFolder
Folder where screenshots are written; the registry file is created here.
.PARAMETER RunGuid
Short GUID string used in the registry filename to keep runs isolated.
.OUTPUTS
[string] Full path to the PID registry file.
#>
function Initialize-PidRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Context,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RunGuid
    )
    # Build the registry file path next to the output frames for easy inspection.
    $path = Join-Path $SaveFolder ".vlc_pids_$RunGuid.txt"

    # Ensure destination folder exists (bubble exceptions so caller can surface one message).
    if (-not (Test-Path -LiteralPath $SaveFolder)) {
        New-Item -ItemType Directory -Path $SaveFolder -Force | Out-Null
    }

    # (Re)create the registry file for this run and write a tiny header.
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType File -Path $path -Force | Out-Null
    $header = "# videoscreenshot PID registry`n# RunGuid=$RunGuid`n# Created=$(Get-Date -Format o)`n"
    Add-ContentWithRetry -Path $path -Value $header

    # Attach to the context so other helpers can append without recomputing the path.
    $Context.PidRegistryPath = $path
    return $path
}
function Register-RunPid {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][psobject]$Context,
        [Parameter(Mandatory)][int]$ProcessId
    )
    if (-not $Context.PidRegistryPath) { throw "PID registry not initialized." }
    # Append an auditable START entry instead of mutating/removing prior lines.
    $line = ("{0}`tSTART`t{1}" -f (Get-Date -Format o), $ProcessId)
    # Be intentionally silent on success; still throw on errors.
    [void](Add-ContentWithRetry -Path $Context.PidRegistryPath -Value $line -ErrorAction Stop)
}

<#
.SYNOPSIS
Append a STOP record for a process to the PID registry.
.DESCRIPTION
Appends a line with ISO-8601 timestamp, the literal 'STOP', and the PID. We
avoid rewriting the file to keep the registry append-only and human-auditable.
.PARAMETER Context
Per-run context containing .PidRegistryPath.
.PARAMETER ProcessId
PID that has exited (or been terminated).
#>
function Unregister-RunPid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Context,
        [Parameter(Mandatory)][int]$ProcessId
    )
    if (-not $Context.PidRegistryPath) { return }
    if (-not (Test-Path -LiteralPath $Context.PidRegistryPath)) { return }
    # Append a STOP entry; callers can correlate START/STOP pairs during diagnostics.
    $line = ("{0}`tSTOP`t{1}" -f (Get-Date -Format o), $ProcessId)
    Add-ContentWithRetry -Path $Context.PidRegistryPath -Value $line
}
