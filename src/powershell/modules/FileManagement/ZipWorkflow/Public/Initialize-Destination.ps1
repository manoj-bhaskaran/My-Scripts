function Initialize-Destination {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory)][string]$DestinationDir)
    if (-not (Test-Path -LiteralPath $DestinationDir)) {
        if ($PSCmdlet.ShouldProcess($DestinationDir, 'Create destination directory')) {
            New-DirectoryIfMissing -Path $DestinationDir -Force | Out-Null
        }
    }
}
