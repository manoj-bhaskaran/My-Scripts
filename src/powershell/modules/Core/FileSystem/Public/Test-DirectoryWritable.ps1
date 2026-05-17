function Test-DirectoryWritable {
    <#
    .SYNOPSIS
        Tests whether a directory can be written to by the current process.

    .DESCRIPTION
        Creates a uniquely named probe subdirectory inside Path, then removes it inside a
        try/finally block so the probe directory is always cleaned up — even when an
        exception is thrown. Returns $true if the probe directory was created successfully,
        $false otherwise.

        If -ThrowOnFailure is specified and the directory is not writable, a terminating
        error is thrown with the message "Directory is not writable: <Path>".

    .PARAMETER Path
        The directory to test for write access.

    .PARAMETER ThrowOnFailure
        When present, throws a terminating error instead of returning $false when the
        directory is not writable or does not exist.

    .EXAMPLE
        Test-DirectoryWritable -Path 'C:\Temp'
        Returns $true if the process can create items inside C:\Temp.

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

    if (-not [System.IO.Directory]::Exists($Path)) {
        if ($ThrowOnFailure) {
            throw "Directory is not writable: $Path"
        }
        return $false
    }

    $probe = Join-Path $Path ("_writable_probe_{0}" -f [guid]::NewGuid().ToString('N'))
    $writable = $false
    try {
        [System.IO.Directory]::CreateDirectory($probe) | Out-Null
        $writable = $true
    } catch {
        Write-Verbose "Write probe failed for '$Path': $($_.Exception.Message)"
    } finally {
        if ([System.IO.Directory]::Exists($probe)) {
            try { [System.IO.Directory]::Delete($probe) } catch { }
        }
    }

    if (-not $writable -and $ThrowOnFailure) {
        throw "Directory is not writable: $Path"
    }
    return $writable
}
