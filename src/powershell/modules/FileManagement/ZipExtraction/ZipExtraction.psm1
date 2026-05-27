#requires -Version 7.0
using namespace System.Collections.Concurrent
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# Provide no-op logging fallbacks for helper-load contexts where the logging framework
# is not imported into the same scope as this module.
if (-not (Get-Command -Name Write-LogInfo -ErrorAction SilentlyContinue)) {
    function Write-LogInfo { param([string]$Message) }
}
if (-not (Get-Command -Name Write-LogDebug -ErrorAction SilentlyContinue)) {
    function Write-LogDebug { param([string]$Message) }
}

# Canonical single-source definition — the script-local duplicate was removed in #1095.
function New-ExtractionSummary {
    param(
        [int]$ZipCount,
        [int]$ProcessedZips,
        [int]$FilesExtracted,
        [int64]$UncompressedBytes,
        [int64]$CompressedBytes
    )
    return [pscustomobject]@{
        ZipCount          = $ZipCount
        ProcessedZips     = $ProcessedZips
        FilesExtracted    = $FilesExtracted
        UncompressedBytes = $UncompressedBytes
        CompressedBytes   = $CompressedBytes
    }
}

# No-op fallback for helper-load test contexts where ProgressReporter is not imported.
# The canonical implementation lives in Core/Progress/Public/Show-ProgressPhase.ps1.
if (-not (Get-Command -Name Show-ProgressPhase -ErrorAction SilentlyContinue)) {
    function Show-ProgressPhase {
        param(
            [Parameter(Mandatory)][string]$Activity,
            [Parameter(Mandatory)][string]$Status,
            [Parameter(Mandatory)][int]$Current,
            [Parameter(Mandatory)][int]$Total,
            [Parameter(Mandatory)][bool]$QuietMode,
            [string]$CurrentOperation,
            [switch]$Completed
        )
        if ($QuietMode) { return }
    }
}

$privateDir = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $privateDir) {
    Get-ChildItem -Path $privateDir -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
}

$publicDir = Join-Path $PSScriptRoot 'Public'
if (Test-Path -LiteralPath $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | ForEach-Object { . $_.FullName }
}

$publicFunctions = if (Test-Path -LiteralPath $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | Select-Object -ExpandProperty BaseName
} else { @() }

Export-ModuleMember -Function $publicFunctions
