function Assert-Pwsh7OrThrow {
    <#
  .SYNOPSIS
  Ensures the host is PowerShell 7+ (PSEdition Core); throws otherwise.
  #>
    try {
        $ver = $PSVersionTable.PSVersion
        $edition = $PSEdition
    }
    catch {
        throw "Unable to determine PowerShell host version."
    }
    if ($null -eq $ver -or $ver.Major -lt 7 -or ($edition -ne 'Core')) {
        $detected = if ($null -ne $ver) { "$ver ($edition)" } else { 'unknown' }
        $msg = @(
            "PowerShell 7+ required. Detected: $detected.",
            "Install PowerShell 7+ and re-run using 'pwsh'.",
            "On Windows, try: winget install --id Microsoft.PowerShell -e",
            "Then run: pwsh -NoProfile -File <your-script>.ps1 ..."
        ) -join [Environment]::NewLine
        throw $msg
    }
}