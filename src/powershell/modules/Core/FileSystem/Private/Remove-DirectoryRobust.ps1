function Remove-DirectoryRobust {
    <#
    .SYNOPSIS
        Deletes a directory using [System.IO.Directory]::Delete with Remove-Item as fallback.
    .DESCRIPTION
        Use [System.IO.Directory]::Delete instead of Remove-Item -Recurse -Force.
        On Linux, PowerShell's Remove-Item has a long-standing rough edge (PowerShell
        #8211) where it can leave the root directory behind on some CI filesystems
        (GitHub Actions runners). The .NET primitive is synchronous and has no such
        quirk. Remove-Item is kept as a fallback only if the .NET call fails.

        Records a single failure entry to ErrorList if the directory still exists after
        both attempts, or if the last delete attempt threw (preserves error reporting
        when permission-denied ACLs might make the directory appear absent while
        deletion genuinely failed).
    #>
    param(
        [Parameter(Mandatory)][string]$ResolvedSource,
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )
    $finalDeleteError = $null
    if ([System.IO.Directory]::Exists($ResolvedSource)) {
        try {
            [System.IO.Directory]::Delete($ResolvedSource, $true)
        } catch {
            $finalDeleteError = $_
            Write-Verbose "Directory.Delete raised for '$ResolvedSource': $($_.Exception.Message)"
        }
    }
    if ([System.IO.Directory]::Exists($ResolvedSource)) {
        try {
            Remove-Item -LiteralPath $ResolvedSource -Recurse -Force -ErrorAction Stop
            $finalDeleteError = $null
        } catch {
            if ($null -eq $finalDeleteError) { $finalDeleteError = $_ }
            Write-Verbose "Remove-Item fallback raised for '$ResolvedSource': $($_.Exception.Message)"
        }
    }
    if ([System.IO.Directory]::Exists($ResolvedSource)) {
        $reason = ($null -ne $finalDeleteError) ? $finalDeleteError.Exception.Message : 'source directory still exists after removal'
        $ErrorList.Add("Failed to delete source directory '$SourceDir': $reason") | Out-Null
    } elseif ($null -ne $finalDeleteError) {
        $ErrorList.Add("Failed to delete source directory '$SourceDir': $($finalDeleteError.Exception.Message)") | Out-Null
    }
}
