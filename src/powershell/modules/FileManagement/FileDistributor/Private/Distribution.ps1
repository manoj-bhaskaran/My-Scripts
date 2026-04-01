# Distribution.ps1 - Subfolder file-count helper for FileDistributor module

function Get-SubfolderFileCounts {
    param(
        [Parameter(Mandatory)][string]$TargetFolder,
        [switch]$IncludeEmpty,
        [object[]]$FallbackSubfolders
    )

    $subfolders = $null
    $scanFailed = $false
    try {
        $subfolders = @(Get-ChildItem -LiteralPath $TargetFolder -Directory -Force -ErrorAction Stop)
    }
    catch {
        $scanFailed = $true
        Write-LogWarning ("Failed to enumerate subfolders under '{0}': {1}" -f $TargetFolder, $_.Exception.Message)
        $subfolders = @()

        if ($FallbackSubfolders -and $FallbackSubfolders.Count -gt 0) {
            Write-LogWarning "Continuing with fallback subfolder candidates after scan failure."
            foreach ($candidate in $FallbackSubfolders) {
                $candidatePath = if ($candidate -is [IO.FileSystemInfo]) { $candidate.FullName } else { [string]$candidate }
                if ([string]::IsNullOrWhiteSpace($candidatePath)) { continue }

                $resolved = Resolve-SubfolderPath -Path $candidatePath -TargetRoot $TargetFolder
                if (-not $resolved) { continue }
                if (-not (Test-Path -LiteralPath $resolved -PathType Container)) { continue }

                try {
                    $normalized = [IO.Path]::GetFullPath($resolved)
                    $subfolders += [pscustomobject]@{ FullName = $normalized }
                }
                catch {
                    continue
                }
            }
        }
    }

    if (-not $subfolders -or $subfolders.Count -eq 0) {
        if ($scanFailed) {
            Write-LogError "No usable fallback subfolders were available after scan failure."
            return $null
        }
        return @{}
    }

    $subfolders = @($subfolders | Sort-Object FullName -Unique)

    $folderCounts = @{}
    $totalFiles = 0
    foreach ($sf in $subfolders) {
        try {
            $count = (Get-ChildItem -LiteralPath $sf.FullName -File -Force -ErrorAction Stop | Measure-Object).Count
        }
        catch {
            Write-LogWarning ("Failed to count files in subfolder '{0}': {1}" -f $sf.FullName, $_.Exception.Message)
            $count = 0
        }

        $totalFiles += [int]$count
        if ($IncludeEmpty -or $count -gt 0) {
            $folderCounts[$sf.FullName] = [int]$count
        }
    }

    if ($totalFiles -eq 0) {
        Write-LogInfo "No files found across target subfolders."
    }

    return $folderCounts
}
