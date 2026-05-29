function Get-NonZipDeletionBlockReason {
    <#
    .SYNOPSIS
        Returns a human-readable block reason when non-zip items prevent deletion, or $null when safe to proceed.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$NonZips,
        [Parameter(Mandatory)][bool]$ShouldCleanNonZips,
        [Parameter(Mandatory)][string]$SourceDir
    )
    if ($NonZips.Count -eq 0 -or $ShouldCleanNonZips) { return $null }
    $hasFiles = @($NonZips | Where-Object { -not $_.PSIsContainer })
    $msg = ($hasFiles.Count -gt 0) ?
        "DeleteSource skipped: non-zip files remain in '$SourceDir'. Use -CleanNonZips to remove them." :
        "DeleteSource skipped: only empty subdirectories remain in '$SourceDir'. Use -CleanNonZips to remove them."
    Write-Verbose ("Remaining items: `n" + ($NonZips | Select-Object -ExpandProperty FullName | Out-String))
    return $msg
}
