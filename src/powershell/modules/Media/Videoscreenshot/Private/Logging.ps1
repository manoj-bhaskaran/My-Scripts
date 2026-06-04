<#
.SYNOPSIS
  Emit a formatted log line to appropriate PowerShell streams.
.DESCRIPTION
  Formats messages as "[yyyy-MM-dd HH:mm:ss] [LEVEL ] Message" and writes to:
    - Information stream for Info
    - Warning stream for Warn (also mirrored to Debug for traceability)
    - Error stream   for Error (also mirrored to Debug)

  Optional behaviors:
    - -LogFile <path> : Append the formatted line to a log file (best-effort).
    - Module default  : When -LogFile is omitted, append to the module-scoped
      default set by Set-VideoScreenshotLogFile, if one is configured.
    - -Quiet          : Suppress console emission for Info/Warn (Error still shown).

  Notes:
    - Info uses the Information stream (`Write-Information -InformationAction Continue`)
      for better pipeline behavior. If that fails (rare), we fall back to Write-Output.
    - Debug echoes for Warn/Error help when collecting verbose traces.
.PARAMETER Level
  Log level classification: Info, Warn, or Error.
.PARAMETER Message
  The message text to log.
.PARAMETER Quiet
  Suppress console emission for Info and Warn (Error is never suppressed).
  LogFile output (when provided) still occurs.
.PARAMETER LogFile
  Path to a file where the log line should be appended. Directory must exist.
  Explicit values take precedence over the module-scoped default; an empty value disables file output for that call.
.EXAMPLE
  Write-Message -Level Info -Message "Starting capture" -LogFile "C:\logs\run.log"
.EXAMPLE
  Write-Message -Level Warn -Message "No videos found" -Quiet
#>
$script:VideoscreenshotLogFile = $null

<#
.SYNOPSIS
  Set the module-scoped default run log file used by Write-Message.
.DESCRIPTION
  Start-VideoBatch uses this helper to route messages from the entrypoint and
  private helpers into one per-run log without threading -LogFile through every
  call site. Pass a null/empty value to clear the sink.
#>
function Set-VideoScreenshotLogFile {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $script:VideoscreenshotLogFile = $null
    }
    else {
        $script:VideoscreenshotLogFile = $Path
    }
}

<#
.SYNOPSIS
  Return the current module-scoped default run log file, if configured.
#>
function Get-VideoScreenshotLogFile {
    [CmdletBinding()]
    param()

    return $script:VideoscreenshotLogFile
}

<#
.SYNOPSIS
  Clear the module-scoped default run log file.
#>
function Clear-VideoScreenshotLogFile {
    [CmdletBinding()]
    param()

    $script:VideoscreenshotLogFile = $null
}

<#
.SYNOPSIS
  Resolve and configure the per-run log file, setting or clearing the module-scoped sink.
.DESCRIPTION
  Branches on NoLogFile, an explicitly-provided LogFile, and the default auto-named path;
  creates the parent directory best-effort; calls Set-VideoScreenshotLogFile or
  Clear-VideoScreenshotLogFile. Returns the resolved path, or $null when logging is disabled.
.PARAMETER SaveFolder
  Folder used to build the default auto-named log path.
.PARAMETER RunGuid
  Short run identifier appended to the default log filename.
.PARAMETER LogFile
  Caller-supplied log path. May be empty to opt out of file logging.
.PARAMETER LogFileExplicitlyProvided
  True when the caller passed -LogFile explicitly (distinguishes empty-string opt-out from omission).
.PARAMETER NoLogFile
  When set, disables file logging entirely regardless of LogFile.
.OUTPUTS
  [string] resolved log path, or $null when logging is disabled.
#>
function Initialize-RunLogFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SaveFolder,
        [Parameter(Mandatory)][string]$RunGuid,
        [AllowEmptyString()][string]$LogFile,
        [bool]$LogFileExplicitlyProvided,
        [switch]$NoLogFile
    )

    if ($NoLogFile -or ($LogFileExplicitlyProvided -and [string]::IsNullOrWhiteSpace($LogFile))) {
        Clear-VideoScreenshotLogFile
        return $null
    }

    $resolvedPath = if ($LogFileExplicitlyProvided) {
        $LogFile
    }
    else {
        Join-Path $SaveFolder ("videoscreenshot_{0}_{1}.log" -f (Get-Date).ToString('yyyyMMdd_HHmmss'), $RunGuid)
    }

    $runLogParent = Split-Path -Path $resolvedPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($runLogParent) -and -not (Test-Path -LiteralPath $runLogParent -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $runLogParent -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning ("Unable to create run log directory '{0}': {1}. File logging will remain best-effort." -f $runLogParent, $_.Exception.Message)
        }
    }

    Set-VideoScreenshotLogFile -Path $resolvedPath
    return $resolvedPath
}

function Write-Message {
    [CmdletBinding()]
    param(
        [ValidateSet('Info', 'Warn', 'Error')][string]$Level = 'Info',
        [Parameter(Mandatory)][string]$Message,
        [switch]$Quiet,
        [AllowEmptyString()]
        [string]$LogFile
    )

    # Prepare formatted line with timestamp + fixed-width level for neat alignment
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $formatted = "[$ts] [$($Level.ToUpper().PadRight(5))] $Message"

    $effectiveLogFile = if ($PSBoundParameters.ContainsKey('LogFile')) {
        $LogFile
    }
    else {
        $script:VideoscreenshotLogFile
    }

    # Best-effort file logging (does not throw the whole function if it fails)
    if (-not [string]::IsNullOrWhiteSpace($effectiveLogFile)) {
        try {
            # Uses helper with retry semantics; caller is responsible for directory existence.
            Add-ContentWithRetry -Path $effectiveLogFile -Value $formatted | Out-Null
        }
        catch {
            # Keep the run going; surface a warning so the user knows file logging failed.
            Write-Warning ("Write-Message: failed to write to logfile '{0}' — {1}" -f $effectiveLogFile, $_.Exception.Message)
        }
    }

    # Quiet mode: suppress Info/Warn on console, but never suppress Error.
    if ($Quiet -and $Level -ne 'Error') { return }

    # Stream selection & fallbacks:
    # - Info: prefer Information stream (pipeline-friendly). Fallback to Host on failure.
    # - Warn/Error: standard streams, and mirrored to Debug for traceability.
    switch ($Level) {
        'Info' {
            try { Write-Information -MessageData $formatted -InformationAction Continue }
            catch { Write-Output $formatted }
        }
        'Warn' { Write-Warning $formatted; Write-Debug $formatted }
        'Error' { Write-Error   $formatted; Write-Debug $formatted }
    }
}
