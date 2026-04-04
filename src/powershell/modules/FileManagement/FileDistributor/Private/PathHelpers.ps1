function New-Ref {
    param($Initial = $null)
    $r = [ref]$null
    $r.Value = $Initial
    return $r
}

function New-Directory {
    param([Parameter(Mandatory = $true)][string]$DirectoryPath)
    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        try { New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null }
        catch { Write-LogDebug "Failed to create directory ${DirectoryPath}: $_" }
    }
    return (Test-Path -LiteralPath $DirectoryPath)
}

function Resolve-PathWithFallback {
    param(
        [string]$UserPath,
        [Parameter(Mandatory = $true)][string]$ScriptRelativePath,
        [Parameter(Mandatory = $true)][string]$WindowsDefaultPath,
        [Parameter(Mandatory = $true)][string]$TempFallbackPath
    )

    if ($UserPath) {
        $parent = Split-Path -Path $UserPath -Parent
        if (New-Directory -DirectoryPath $parent) { return $UserPath }
    }

    $scriptRoot = if ($script:ScriptRoot) { $script:ScriptRoot } elseif ($PSScriptRoot) { Split-Path -Path $PSScriptRoot -Parent } else { (Get-Location).Path }

    $scriptCandidate = Join-Path -Path $scriptRoot -ChildPath $ScriptRelativePath
    $parent = Split-Path -Path $scriptCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $scriptCandidate }

    $winCandidate = $WindowsDefaultPath
    $parent = Split-Path -Path $winCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $winCandidate }

    $tempCandidate = $TempFallbackPath
    $parent = Split-Path -Path $tempCandidate -Parent
    if (New-Directory -DirectoryPath $parent) { return $tempCandidate }

    return $TempFallbackPath
}

function Resolve-FilePathIfDirectory {
    param(
        [Parameter(Mandatory = $true)][ref]$Path,
        [Parameter(Mandatory = $true)][string]$DefaultFileName
    )
    $p = $Path.Value
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    try {
        if (Test-Path -LiteralPath $p -PathType Container) {
            $Path.Value = (Join-Path -Path $p -ChildPath $DefaultFileName)
            return
        }
    }
    catch {
        Write-LogDebug "Failed to test path ${p}: $_"
    }
    if ($p -match '[\\/]\s*$') {
        $Path.Value = (Join-Path -Path $p -ChildPath $DefaultFileName)
        return
    }
}

function Initialize-FilePath {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [switch]$CreateFile
    )
    $dir = Split-Path -Path $FilePath -Parent
    if ($dir) { [void][System.IO.Directory]::CreateDirectory($dir) }
    if ($CreateFile -and -not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { New-Item -ItemType File -Path $FilePath -Force | Out-Null }
}

function Resolve-SubfolderPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [ref]$WarningCount = $null
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ($Path -match '^[A-Za-z]$' -or $Path -match '^[A-Za-z]:$' -or $Path -match '^[A-Za-z]:[^\\/].*') { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        try {
            Write-LogDebug "DEBUG: Attempting GetFullPath for '$Path'"
            return [IO.Path]::GetFullPath($Path)
        }
        catch {
            Write-LogWarning "DEBUG: GetFullPath threw for '$Path': $($_.Exception.Message)"
            if ($WarningCount) { $WarningCount.Value++ }
            return $null
        }
    }
    return (Join-Path -Path $TargetRoot -ChildPath $Path)
}
