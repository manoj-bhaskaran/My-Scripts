function Test-LongPathsEnabled {
    <#
    .SYNOPSIS
        Checks whether LongPathsEnabled is set in the Windows OS registry.

    .DESCRIPTION
        Queries the registry key HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem
        to determine if LongPathsEnabled is enabled (value = 1).
        This enables Windows to support paths longer than the traditional 260-character limit.

        Note: Enabling long paths via registry or Group Policy is a system-wide
        configuration that may require administrative privileges to set.

    .EXAMPLE
        Test-LongPathsEnabled
        Returns: $true (if LongPathsEnabled = 1 in registry)

    .EXAMPLE
        if (Test-LongPathsEnabled) { Write-Host "Long paths are enabled" }
        Performs a check before processing long file paths.

    .OUTPUTS
        [bool] $true if LongPathsEnabled = 1; $false otherwise or if the key is not found.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $val = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
            -Name LongPathsEnabled -ErrorAction Stop
        return ($val.LongPathsEnabled -eq 1)
    } catch {
        Write-Verbose "LongPathsEnabled registry key not found or not readable: $_"
        return $false
    }
}
