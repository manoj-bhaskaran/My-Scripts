function Test-DirectoryWritable {
    <#
    .SYNOPSIS
        Tests whether a directory can be written to by the current process.

    .DESCRIPTION
        Creates a uniquely named probe file inside Path, then removes it inside a
        try/finally block so the probe is always cleaned up — even when an exception
        is thrown. A file probe is used rather than a subdirectory so that the check
        validates the "Create files / write data" ACE, which is the permission actually
        required for file-write operations like Move-Item.

        Returns $true if the probe file was created successfully, $false otherwise.

        If -ThrowOnFailure is specified and the directory is not writable, a terminating
        error is thrown with the message "Directory is not writable: <Path>".

    .PARAMETER Path
        The directory to test for write access.

    .PARAMETER ThrowOnFailure
        When present, throws a terminating error instead of returning $false when the
        directory is not writable or does not exist.

    .EXAMPLE
        Test-DirectoryWritable -Path 'C:\Temp'
        Returns $true if the process can create files inside C:\Temp.

    .EXAMPLE
        Test-DirectoryWritable -Path $dest -ThrowOnFailure
        Throws "Directory is not writable: <dest>" if the directory is read-only.

    .OUTPUTS
        [bool] True if writable, False otherwise (unless -ThrowOnFailure is set).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$ThrowOnFailure
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        if ($ThrowOnFailure) {
            throw "Directory is not writable: $Path"
        }
        return $false
    }

    $probe = Join-Path $Path ("_writable_probe_{0}.tmp" -f [guid]::NewGuid().ToString('N'))
    $writable = $false
    try {
        New-Item -ItemType File -Path $probe -ErrorAction Stop | Out-Null
        $writable = $true
    } catch {
        Write-Verbose "Write probe failed for '$Path': $($_.Exception.Message)"
    } finally {
        if (Test-Path -LiteralPath $probe) {
            try { Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue } catch { Write-Verbose "Probe cleanup failed for '$probe': $($_.Exception.Message)" }
        }
    }

    if (-not $writable -and $ThrowOnFailure) {
        throw "Directory is not writable: $Path"
    }
    return $writable
}
