#requires -PSEdition Core
#requires -Version 7.0

# Robust module loader: guard for missing dirs and deterministic load order
$here = Split-Path -Parent $PSCommandPath
$privateDir = Join-Path $here 'Private'
$publicDir  = Join-Path $here 'Public'

foreach ($dir in @($privateDir, $publicDir)) {
    if (Test-Path -LiteralPath $dir) {
        Get-ChildItem -LiteralPath $dir -Filter *.ps1 -File -ErrorAction SilentlyContinue |
            Sort-Object -Property Name |
            ForEach-Object {
                try {
                    . $_.FullName
                } catch {
                    throw "Failed to load $($_.FullName): $($_.Exception.Message)"
                }
            }
    } else {
        # Directory is optional at runtime (e.g., partial checkout or phased refactor)
        Write-Debug "Module load: optional directory not found: $dir"
    }
}

# Export public API (explicit to avoid accidental exports)
Export-ModuleMember -Function Start-VideoBatch