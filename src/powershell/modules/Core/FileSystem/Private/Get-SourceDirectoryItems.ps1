function Get-SourceDirectoryItems {
    <#
    .SYNOPSIS
        Reads all items under SourceDir recursively, surfacing enumeration errors as warnings.
    #>
    param([Parameter(Mandatory)][string]$SourceDir)
    $gcErrors = $null
    $items = Get-ChildItem -LiteralPath $SourceDir -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable gcErrors
    foreach ($e in $gcErrors) {
        Write-Warning "Could not read item during source directory scan: $($e.Exception.Message)"
    }
    return @($items)
}
