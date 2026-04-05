# Invoke-DistributionLockRelease.ps1 - Release a held distribution state file lock (public module function)

function Invoke-DistributionLockRelease {
    param(
        [Parameter(Mandatory = $true)]$FileStream
    )
    Unlock-DistributionStateFile -FileStream $FileStream
}
