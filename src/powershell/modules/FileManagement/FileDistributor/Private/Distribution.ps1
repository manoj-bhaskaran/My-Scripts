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

function Write-DistributionSummary {
    param(
        [Parameter(Mandatory)][hashtable]$FolderCounts,
        [Parameter(Mandatory)][double]$Average,
        [string]$Label = "CURRENT DISTRIBUTION",
        [int]$UpperBound = -1,
        [int]$LowerBound = -1
    )

    if ($Label -match '===') {
        Write-LogInfo $Label
    } else {
        Write-LogInfo "=== $Label ==="
    }
    foreach ($folderPath in ($FolderCounts.Keys | Sort-Object { [int]$FolderCounts[$_] } -Descending)) {
        $count = [int]$FolderCounts[$folderPath]
        $folderName = Split-Path -Leaf $folderPath
        $deviation = $count - $Average
        $deviationPct = if ($Average -gt 0) { ($deviation / $Average) * 100 } else { 0 }

        if ($UpperBound -ge 0 -and $LowerBound -ge 0) {
            $status = if ($count -gt $UpperBound) { "DONOR" } elseif ($count -lt $LowerBound) { "RECEIVER" } else { "BALANCED" }
            Write-LogInfo ("  {0}: {1} files (avg {2:+0.0;-0.0;0}%, {3:+0;-0;0} files) [{4}]" -f $folderName, $count, $deviationPct, $deviation, $status)
        } else {
            Write-LogInfo ("  {0}: {1} files (avg {2:+0.0;-0.0;0}%, {3:+0;-0;0} files)" -f $folderName, $count, $deviationPct, $deviation)
        }
    }
}
