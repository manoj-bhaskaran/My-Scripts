function Test-HostTar {
    <#
.SYNOPSIS
    Verifies tar.exe is available on the host when using tar mode.
.PARAMETER Mode
    Transfer mode. When not Tar, the check is skipped.
.OUTPUTS
    None. Throws on failure if tar mode is requested and tar is unavailable.
#>
    param(
        [ValidateSet('Pull', 'Tar')]
        [string]$Mode = 'Tar'
    )

    if ($Mode -ne 'Tar') {
        return
    }

    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
        throw 'Windows tar.exe not found. Use pull mode (-Resume) or install tar and add to PATH.'
    }
}
