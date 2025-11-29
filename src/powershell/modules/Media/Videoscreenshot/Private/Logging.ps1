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
    - -Quiet          : Suppress console emission for Info/Warn (Error still shown).

  Notes:
    - Info uses the Information stream (`Write-Information -InformationAction Continue`)
      for better pipeline behavior. If that fails (rare), we fall back to Write-Host.
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
.EXAMPLE
  Write-Message -Level Info -Message "Starting capture" -LogFile "C:\logs\run.log"
.EXAMPLE
  Write-Message -Level Warn -Message "No videos found" -Quiet
#>
function Write-Message {
    [CmdletBinding()]
    param(
        [ValidateSet('Info', 'Warn', 'Error')][string]$Level = 'Info',
        [Parameter(Mandatory)][string]$Message,
        [switch]$Quiet,
        [string]$LogFile
    )

    # Prepare formatted line with timestamp + fixed-width level for neat alignment
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $formatted = "[$ts] [$($Level.ToUpper().PadRight(5))] $Message"

    # Best-effort file logging (does not throw the whole function if it fails)
    if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
        try {
            # Uses helper with retry semantics; caller is responsible for directory existence.
            Add-ContentWithRetry -Path $LogFile -Value $formatted | Out-Null
        }
        catch {
            # Keep the run going; surface a warning so the user knows file logging failed.
            Write-Warning ("Write-Message: failed to write to logfile '{0}' — {1}" -f $LogFile, $_.Exception.Message)
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
            catch { Write-Host $formatted -ForegroundColor Cyan }
        }
        'Warn' { Write-Warning $formatted; Write-Debug $formatted }
        'Error' { Write-Error   $formatted; Write-Debug $formatted }
    }
}
