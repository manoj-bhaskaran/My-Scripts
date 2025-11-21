<#
.SYNOPSIS
  Append a line to a file with retry and exclusive write semantics.
.DESCRIPTION
  Opens the destination file with exclusive access (no sharing) and appends the
  provided value followed by a newline. Retries transient I/O failures (e.g.,
  AV scans or brief locks) with linear backoff. Succeeds or throws; no partial
  returns. Returns $true on success.
.PARAMETER Path
  Destination file path (created if it does not exist).
.PARAMETER Value
  The string to append (a newline is automatically added).
.PARAMETER MaxAttempts
  Maximum number of attempts (default: 3). Backoff is 200ms × attempt number.
.OUTPUTS
  [bool] $true on success. Errors are thrown on failure.
.EXAMPLE
  Add-ContentWithRetry -Path "$env:TEMP\log.txt" -Value "hello"
#>
function Add-ContentWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Value,
        [ValidateRange(1, 10)][int]$MaxAttempts = 3
    )
    # Contract: succeeds or throws. No partial returns.
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        $fs = $null
        try {
            # Build the payload (value + newline) once per attempt.
            $nl = [Environment]::NewLine
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value + $nl)
            # Exclusive append prevents interleaving writes from other processes.
            $fs = [System.IO.File]::Open(
                $Path,
                [System.IO.FileMode]::Append,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
            $fs.Write($bytes, 0, $bytes.Length)
            return $true
        }
        catch {
            if ($i -ge $MaxAttempts) {
                throw ("Failed to append to '{0}' after {1} attempts: {2}" -f $Path, $MaxAttempts, $_.Exception.Message)
            }
            # Linear backoff helps absorb transient sharing violations / AV scans.
            Start-Sleep -Milliseconds (200 * $i)
        }
        finally {
            if ($null -ne $fs) {
                try { $fs.Dispose() } catch { }
            }
        }
    }
}
<#
.SYNOPSIS
  Verify that a folder exists and is writable.
.DESCRIPTION
  By default, creates the folder if missing, then performs an exclusive write
  probe using a temporary file to confirm effective write permission (ACL +
  share). If -NoCreate is specified, the function will throw if the folder does
  not exist. Returns $true on success; throws with a descriptive error on failure.
.PARAMETER Folder
  Target directory to validate.
.PARAMETER NoCreate
  Do not create the folder if it is missing. Throw instead.
.OUTPUTS
  [bool] $true on success. Errors are thrown on failure.
.EXAMPLE
  Test-FolderWritable -Folder 'C:\Screenshots'
.EXAMPLE
  Test-FolderWritable -Folder '/mnt/share' -NoCreate
#>
function Test-FolderWritable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Folder,
        [Alias('CheckOnly')][switch]$NoCreate
    )
    try {
        # Create the folder unless the caller explicitly disabled creation.
        if (-not (Test-Path -LiteralPath $Folder)) {
            if ($NoCreate) { throw "Folder does not exist and -NoCreate was specified: $Folder" }
            New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        }
        # Exclusive write probe: ensures we can create and write a brand new file.
        $tmp = Join-Path $Folder (".writetest_{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
        $fs = $null
        try {
            $fs = [System.IO.File]::Open($tmp, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('ok')
            $fs.Write($bytes, 0, $bytes.Length)
        }
        finally {
            if ($fs) { try { $fs.Dispose() } catch { } }
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        return $true
    }
    catch {
        throw "Folder is not writable: $Folder – $($_.Exception.Message)"
    }
}