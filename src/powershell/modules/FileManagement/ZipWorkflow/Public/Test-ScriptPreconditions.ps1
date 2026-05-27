function Test-ScriptPreconditions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestinationDir
    )
    $srcFull = Get-FullPath -Path $SourceDir
    $dstFull = Get-FullPath -Path $DestinationDir
    if ($srcFull -eq $dstFull) { throw "Source and destination cannot be the same: $srcFull" }
    if (Test-PathContainment -Container $srcFull -Candidate $dstFull) { throw 'Destination cannot be inside the source directory.' }
    if (Test-PathContainment -Container $dstFull -Candidate $srcFull) { throw 'Source cannot be inside the destination directory.' }
    if (-not (Test-Path -LiteralPath $SourceDir)) { throw "Source directory not found: $SourceDir" }
    if (-not (Test-LongPathsEnabled)) { Write-LogDebug 'LongPathsEnabled=0; consider enabling to avoid path-length issues.' }
}
