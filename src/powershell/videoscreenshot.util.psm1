<#
.SYNOPSIS
Utility helpers for videoscreenshot.ps1.

.DESCRIPTION
Optional helpers (logging + safe file append). Loaded by the script if present.
Versioning and changelog are tracked by the main script/release tags.

.NOTES
Author: Manoj Bhaskaran
Streams: Warn/Error go to native streams (Write-Warning / Write-Error).
Info is sent to Information stream (when enabled) and to host for visibility.
#>

function Write-Message {
    <#
    .SYNOPSIS
    Structured console logging with timestamp and color.
    .PARAMETER Level
    One of Info, Warn, Error.
    .PARAMETER Message
    Text to print.
    #>
    param(
        [ValidateSet('Info','Warn','Error')]
        [string]$Level = 'Info',
        [Parameter(Mandatory)][string]$Message
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $prefixed = "[$ts] [$($Level.ToUpper().PadRight(5))] $Message"
    switch ($Level) {
        'Warn'  { Write-Warning $prefixed }
        'Error' { Write-Error   $prefixed }
        Default {
            try { Write-Information $prefixed } catch {}
            Write-Host $prefixed -ForegroundColor Cyan
        }
    }
}

function Add-ContentWithRetry {
    <#
    .SYNOPSIS
    Append to a file with limited retries to absorb transient locks.
    .DESCRIPTION
    Attempts an exclusive append to avoid interleaved writes across processes.
    .PARAMETER Path
    Target file.
    .PARAMETER Value
    Line of text to append.
    .PARAMETER MaxAttempts
    Retry attempts (default 3).
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Value,
        [int]$MaxAttempts = 3
    )
    for ($i=1; $i -le $MaxAttempts; $i++) {
        try {
            $newline = [Environment]::NewLine
            $bytes   = [System.Text.Encoding]::UTF8.GetBytes($Value + $newline)
            $fs = [System.IO.File]::Open($Path,
                [System.IO.FileMode]::Append,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None) # exclusive append
            $fs.Write($bytes, 0, $bytes.Length)
            $fs.Close()
            return $true
        } catch {
            if ($i -eq $MaxAttempts) {
                Write-Message -Level Error -Message "Failed to append to ${Path}: $($_.Exception.Message)"
                return $false
            }
            Start-Sleep -Milliseconds (200 * $i)
        }
    }
}

Export-ModuleMember -Function Write-Message,Add-ContentWithRetry
