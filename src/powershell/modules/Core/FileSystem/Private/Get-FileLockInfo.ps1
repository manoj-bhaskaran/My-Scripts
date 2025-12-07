function Get-FileLockInfo {
    <#
    .SYNOPSIS
        Gets detailed information about what process is locking a file.

    .DESCRIPTION
        Internal helper function that attempts to identify which process
        has a lock on the specified file. This is a best-effort function
        and may not work in all scenarios.

    .PARAMETER Path
        File path to check

    .OUTPUTS
        [PSCustomObject] Object containing lock information, or $null if not locked.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    # First check if the file is locked
    if (-not (Test-FileLocked -Path $Path)) {
        return $null
    }

    $lockInfo = [PSCustomObject]@{
        FilePath    = $Path
        IsLocked    = $true
        ProcessId   = $null
        ProcessName = $null
    }

    try {
        # On Windows, we can try to use handles utility or WMI
        # This is a simplified version - full implementation would
        # require external tools or P/Invoke
        if ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            # Try to find the process using the file
            # This is a basic implementation and may not catch all cases
            $fileName = Split-Path -Path $Path -Leaf

            # Try to find processes that might be using the file
            $processes = Get-Process | Where-Object {
                try {
                    $_.Modules.FileName -contains $Path
                }
                catch {
                    $false
                }
            }

            if ($processes) {
                $lockInfo.ProcessId = $processes[0].Id
                $lockInfo.ProcessName = $processes[0].ProcessName
            }
        }
    }
    catch {
        Write-Verbose "Could not determine locking process: $_"
    }

    return $lockInfo
}
