function Remove-NonZipItems {
    <#
    .SYNOPSIS
        Removes non-zip items deepest-first to avoid "directory not empty" errors on nested trees.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$NonZips,
        [Parameter(Mandatory)][string]$ResolvedSource
    )
    # Wrap the split/filter result with @(...) so .Count remains valid under
    # Set-StrictMode -Version Latest when a single-segment relative path
    # would otherwise make Where-Object return a scalar string.
    $NonZips | Sort-Object -Property `
        @{ Expression = { @($_.FullName -replace [regex]::Escape($ResolvedSource), '' -split '[\\/]' | Where-Object { $_ -ne '' }).Count }; Descending = $true }, `
        @{ Expression = { $_.FullName }; Descending = $true } | ForEach-Object {
        # Capture the pipeline item; inside the catch below, $_ is rebound
        # to the ErrorRecord and reading $_.FullName would raise a
        # terminating PropertyNotFoundException under Set-StrictMode -Latest,
        # which would bubble past this catch into the outer handler and
        # prevent the final source-directory deletion from running.
        $item = $_
        try {
            if (Test-Path -LiteralPath $item.FullName) {
                Remove-Item -LiteralPath $item.FullName -Force -Recurse
            }
        } catch {
            Write-Verbose "Best-effort cleanup skip for '$($item.FullName)': $($_.Exception.Message)"
        }
    }
}
