function Remove-SourceDirectory {
    <#
    .SYNOPSIS
        Optionally cleans non-zip leftovers and removes the source directory.
    .DESCRIPTION
        Orchestrates provider-path resolution, blocking-zip detection, non-zip
        classification, best-effort non-zip cleanup, and robust directory deletion.
        Appends human-readable entries to ErrorList rather than throwing, so the
        caller's run continues uninterrupted on partial failures.

        Supports -WhatIf and -Confirm: all destructive file-system operations
        (non-zip cleanup and directory deletion) are guarded by a single
        ShouldProcess call so that dry-run invocations leave the directory intact.
    .PARAMETER SourceDir
        The source directory to conditionally delete.
    .PARAMETER ShouldDeleteSource
        When $false, returns immediately without touching the filesystem.
    .PARAMETER ShouldCleanNonZips
        When $true, non-zip items are deleted before the directory is removed.
        When $false, the presence of any non-zip items adds a block-reason entry
        to ErrorList and leaves the directory intact.
    .PARAMETER ErrorList
        Mutable list of string error messages. Block reasons and delete failures
        are appended here rather than thrown.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][bool]$ShouldDeleteSource,
        [Parameter(Mandatory)][bool]$ShouldCleanNonZips,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )

    if (-not $ShouldDeleteSource) { return }

    # Resolve to the native provider path so [System.IO.Directory] calls (which
    # are unaware of PowerShell PSDrives) see exactly the same path PowerShell
    # does. Without this, a caller passing e.g. `TestDrive:\source-nested`
    # would make Directory.Exists return $false (invalid path to .NET) while
    # Test-Path correctly reported $true, causing the delete logic to short-
    # circuit silently and leave the directory on disk.
    $resolvedSource = try {
        (Resolve-Path -LiteralPath $SourceDir -ErrorAction Stop).ProviderPath
    } catch {
        $SourceDir
    }

    try {
        $remaining = @(Get-SourceDirectoryItems -SourceDir $resolvedSource)
        if (Test-HasBlockingZips -Remaining $remaining -SourceDir $SourceDir -ErrorList $ErrorList) { return }

        $nonZips = @($remaining | Where-Object { $_.PSIsContainer -or $_.Extension -ne '.zip' })
        $blockReason = Get-NonZipDeletionBlockReason -NonZips $nonZips -ShouldCleanNonZips $ShouldCleanNonZips -SourceDir $SourceDir
        if ($blockReason) {
            $ErrorList.Add($blockReason) | Out-Null
            return
        }

        if (-not $PSCmdlet.ShouldProcess($SourceDir, 'Delete source directory')) { return }

        if ($ShouldCleanNonZips -and $nonZips.Count -gt 0) {
            Remove-NonZipItems -NonZips $nonZips -ResolvedSource $resolvedSource
        }

        Remove-DirectoryRobust -ResolvedSource $resolvedSource -SourceDir $SourceDir -ErrorList $ErrorList
    } catch {
        $msg = "Failed to delete source directory '$SourceDir': $($_.Exception.Message)"
        Write-Verbose $msg
        $ErrorList.Add($msg) | Out-Null
    }
}
