function Test-IsElevated {
    <#
    .SYNOPSIS
        Checks if script is running with elevated privileges.

    .DESCRIPTION
        Determines if the current PowerShell session is running with administrator
        privileges on Windows or root privileges on Linux/macOS.

    .EXAMPLE
        if (Test-IsElevated) {
            Write-Output "Running with admin privileges"
        }

    .OUTPUTS
        [bool] True if running with elevated privileges, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Check if running on Windows
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = [Security.Principal.WindowsPrincipal]$identity
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            Write-Warning "Failed to check Windows elevation status: $_"
            return $false
        }
    }
    else {
        # Linux/macOS: check if running as root (UID 0)
        try {
            $uid = & id -u
            return ($uid -eq 0)
        }
        catch {
            Write-Warning "Failed to check Unix elevation status: $_"
            return $false
        }
    }
}
