function Import-RandomNameProvider {
    <#
    .SYNOPSIS
        Ensures the RandomName provider is loaded.

    .DESCRIPTION
        Imports the RandomName module when Get-RandomFileName is not already available.
        Resolution order:
        1) Explicit module path (psd1/psm1/module folder)
        2) Conventional script-root locations
        3) PSModulePath module name import

    .PARAMETER ModulePath
        Optional explicit module path to a psd1/psm1 or module directory.

    .PARAMETER ScriptRoot
        Optional caller script root used for conventional path probing.

    .EXAMPLE
        Import-RandomNameProvider -ModulePath 'C:\Modules\RandomName\RandomName.psd1'

    .EXAMPLE
        Import-RandomNameProvider -ScriptRoot $PSScriptRoot
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ModulePath,

        [Parameter(Mandatory = $false)]
        [string]$ScriptRoot
    )

    function Write-RandomNameProviderLog {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('Info', 'Warning', 'Error')]
            [string]$Level,

            [Parameter(Mandatory = $true)]
            [string]$Message
        )

        switch ($Level) {
            'Info' {
                if (Get-Command -Name Write-LogInfo -ErrorAction SilentlyContinue) {
                    Write-LogInfo $Message
                }
                else {
                    Write-Verbose $Message
                }
            }
            'Warning' {
                if (Get-Command -Name Write-LogWarning -ErrorAction SilentlyContinue) {
                    Write-LogWarning $Message
                }
                else {
                    Write-Warning $Message
                }
            }
            'Error' {
                if (Get-Command -Name Write-LogError -ErrorAction SilentlyContinue) {
                    Write-LogError $Message
                }
                else {
                    Write-Error $Message
                }
            }
        }
    }

    if (Get-Command -Name Get-RandomFileName -ErrorAction SilentlyContinue) {
        Write-RandomNameProviderLog -Level Info -Message 'RandomName provider already available (Get-RandomFileName found).'
        return
    }

    if ($ModulePath) {
        try {
            $resolved = Resolve-Path -LiteralPath $ModulePath -ErrorAction Stop
            Import-Module -Name $resolved.Path -Force -ErrorAction Stop
            Write-RandomNameProviderLog -Level Info -Message "Imported RandomName module from '$($resolved.Path)'."
            return
        }
        catch {
            Write-RandomNameProviderLog -Level Warning -Message "Failed to import RandomName module from '$ModulePath': $($_.Exception.Message)"
        }
    }

    if ($ScriptRoot) {
        $normalizedScriptRoot = $ScriptRoot -replace '[\\/]+$', ''
        $scriptRootCandidates = @(
            "$normalizedScriptRoot\powershell\module\RandomName\RandomName.psd1",
            "$normalizedScriptRoot\powershell\module\RandomName\RandomName.psm1",
            "$normalizedScriptRoot\powershell\modules\Utilities\RandomName\RandomName.psd1",
            "$normalizedScriptRoot\powershell\modules\Utilities\RandomName\RandomName.psm1"
        )

        foreach ($candidate in $scriptRootCandidates) {
            if (Test-Path -LiteralPath $candidate) {
                try {
                    Import-Module -Name $candidate -Force -ErrorAction Stop
                    Write-RandomNameProviderLog -Level Info -Message "Imported RandomName module from script-root '$candidate'."
                    return
                }
                catch {
                    Write-RandomNameProviderLog -Level Warning -Message "Failed to import RandomName module from '$candidate': $($_.Exception.Message)"
                }
            }
        }
    }

    try {
        Import-Module -Name RandomName -ErrorAction Stop
        Write-RandomNameProviderLog -Level Info -Message 'Imported RandomName module from PSModulePath.'
        return
    }
    catch {
        Write-RandomNameProviderLog -Level Error -Message "Failed to import 'RandomName' from PSModulePath: $($_.Exception.Message)"
        throw 'Random name provider (module) not found.'
    }
}
