# Module loader for ProgressReporter

$fileSystemModule = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\FileSystem\FileSystem.psm1'))
if (-not (Test-Path -LiteralPath $fileSystemModule)) {
    throw "Required module dependency not found: $fileSystemModule"
}

# Only import FileSystem when it is not already loaded from the same path. A blind
# `Import-Module -Force` from inside this module's session state would Remove-Module the
# existing (caller/global-scoped) FileSystem and re-import it privately into this module,
# stripping its functions (Get-FullPath, etc.) from every other module's view and from the
# caller's scope. Skipping when already present keeps FileSystem shared across the session.
$modulePathComparer = if ($IsWindows) {
    [System.StringComparer]::OrdinalIgnoreCase
} else {
    [System.StringComparer]::Ordinal
}
$loadedFileSystem = Get-Module -Name 'FileSystem' | Where-Object {
    $_.Path -and $modulePathComparer.Equals([System.IO.Path]::GetFullPath($_.Path), $fileSystemModule)
} | Select-Object -First 1
if (-not $loadedFileSystem) {
    Import-Module $fileSystemModule -Force -ErrorAction Stop
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
}
else {
    @()
}

Export-ModuleMember -Function $publicFunctions
