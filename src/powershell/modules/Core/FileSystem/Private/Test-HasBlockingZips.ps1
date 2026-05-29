function Test-HasBlockingZips {
    <#
    .SYNOPSIS
        Returns $true and records an error when zip files remain and would be destroyed by deletion.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Remaining,
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )
    $remainingZips = @($Remaining | Where-Object { -not $_.PSIsContainer -and $_.Extension -eq '.zip' })
    if ($remainingZips.Count -gt 0) {
        $ErrorList.Add("DeleteSource skipped: $($remainingZips.Count) zip file(s) remain in '$SourceDir' (not moved due to Skip collision policy). Resolve the collisions or change -CollisionPolicy before using -DeleteSource.") | Out-Null
        Write-Verbose ("Remaining zips: `n" + ($remainingZips | Select-Object -ExpandProperty FullName | Out-String))
        return $true
    }
    return $false
}
