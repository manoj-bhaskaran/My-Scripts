#requires -PSEdition Core
#requires -Version 7.0

<#
.SYNOPSIS
  Videoscreenshot module loader.
.DESCRIPTION
  Imports all public/private functions in a deterministic order while guarding for
  missing folders. This file is intentionally small: it only dot-sources scripts
  and exports the public surface.

  Layout:
    Public/  - exported cmdlets and functions (e.g., Start-VideoBatch)
    Private/ - internal helpers (not exported)

  Notes:
    - Files are loaded alphabetically to ensure deterministic initialization.
    - Errors from inaccessible files are surfaced as warnings.
    - If Start-VideoBatch fails to load, import aborts with a clear message.
#>

# Robust module loader: guard for missing dirs and deterministic load order
$here = Split-Path -Parent $PSCommandPath
$privateDir = Join-Path $here 'Private'
$publicDir  = Join-Path $here 'Public'

foreach ($dir in @($privateDir, $publicDir)) {
    if (Test-Path -LiteralPath $dir) {
        # Collect files; surface any enumeration errors as warnings
        $ev = @()
        $files = Get-ChildItem -LiteralPath $dir -Filter *.ps1 -File -ErrorAction SilentlyContinue -ErrorVariable +ev
        if ($ev.Count -gt 0) {
            $unique = $ev | ForEach-Object { $_.Exception.Message } | Select-Object -Unique
            foreach ($m in $unique) {
                Write-Warning ("Module load: issues enumerating {0} — {1}" -f $dir, $m)
            }
        }
        $files |
            Sort-Object -Property Name |
            ForEach-Object {
                $file = $_
                try {
                    . $file.FullName
                } catch {
                    $pos   = $PSItem.InvocationInfo
                    $posMsg = if ($null -ne $pos) { $pos.PositionMessage } else { "" }
                    $stack = $PSItem.ScriptStackTrace
                    $err   = $PSItem.Exception.Message
                    throw ("Failed to load script: {0}`n{1}`nException: {2}`nStack: {3}" -f $file.FullName, $posMsg, $err, $stack)
                }
            }
    } else {
        # Directory is optional at runtime (e.g., partial checkout or phased refactor)
        Write-Debug "Module load: optional directory not found: $dir"
    }
}

# Ensure the public entrypoint actually loaded before exporting
if (-not (Get-Command -Name Start-VideoBatch -ErrorAction SilentlyContinue)) {
    throw "Start-VideoBatch not loaded. Ensure Public/Start-VideoBatch.ps1 exists and loaded without errors."
}

# Export public API (explicit to avoid accidental exports)
Export-ModuleMember -Function Start-VideoBatch