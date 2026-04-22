# New-FileDistributorRunState.ps1 - Factory for FileDistributorRunState (public module function)
#
# The FileDistributorRunState class is defined inside this module. PowerShell's
# Import-Module does not export class types to the caller's scope, so entry
# scripts that use `Import-Module` cannot invoke [FileDistributorRunState]::new()
# directly. This factory runs in module scope where the type is visible and
# returns a fresh instance to the caller.

function New-FileDistributorRunState {
    [CmdletBinding()]
    [OutputType([FileDistributorRunState])]
    param()

    return [FileDistributorRunState]::new()
}
