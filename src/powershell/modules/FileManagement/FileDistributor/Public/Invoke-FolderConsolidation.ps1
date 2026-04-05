# Invoke-FolderConsolidation.ps1 - Consolidation algorithm (public module function)

function Invoke-FolderConsolidation {
    param (
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [Parameter(Mandatory = $true)][int]$FilesPerFolderLimit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)]$FilesToDelete,
        [Parameter(Mandatory = $true)][ref]$GlobalFileCounter,
        [Parameter(Mandatory = $true)][ref]$WarningCount,
        [Parameter(Mandatory = $true)][ref]$ErrorCount,
        [Parameter(Mandatory = $true)][int]$RetryDelay,
        [Parameter(Mandatory = $true)][int]$RetryCount,
        [int]$MaxBackoff = 60
    )

    Write-LogInfo "Consolidation: computing minimal subfolder set..."

    $folderCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -eq $folderCounts) { return }
    $subfolderPaths = @($folderCounts.Keys)
    $totalFiles = [int](($folderCounts.Values | Measure-Object -Sum).Sum)
    $subfolders = @($subfolderPaths | ForEach-Object { [pscustomobject]@{ FullName = $_ } })

    if (-not $subfolders -or $subfolders.Count -eq 0) {
        Write-LogInfo "Consolidation: no subfolders present; nothing to do."
        return
    }

    try {
        $rootResidual = (Get-ChildItem -LiteralPath $TargetFolder -File -Force -ErrorAction Stop | Measure-Object).Count
        if ($rootResidual -gt 0) {
            Write-LogWarning "Consolidation: found $rootResidual file(s) in target root. They will be moved during consolidation."
            $WarningCount.Value++
            $totalFiles += [int]$rootResidual
        }
    } catch {
        Write-LogWarning "Consolidation: failed to check target root for residual files: $($_.Exception.Message)"
        $WarningCount.Value++
    }

    if ($totalFiles -le 0) {
        Write-LogInfo "Consolidation: no files to consolidate."
        return
    }

    $needed = [Math]::Ceiling([double]$totalFiles / [double]$FilesPerFolderLimit)
    if ($needed -lt 1) { $needed = 1 }

    $existingCount = $subfolders.Count
    Write-LogInfo ("Consolidation: totalFiles={0}, limit={1}, existingSubfolders={2}, needed={3}" -f $totalFiles, $FilesPerFolderLimit, $existingCount, $needed)
    $avgBefore = if ($existingCount -gt 0) { [double]$totalFiles / [double]$existingCount } else { 0.0 }
    Write-DistributionSummary -FolderCounts $folderCounts -Average $avgBefore -Label "Consolidation: === CURRENT DISTRIBUTION ==="

    if ($existingCount -le $needed) {
        Write-LogInfo "Consolidation: already at or below minimal subfolder count ($existingCount ≤ $needed). Nothing to do."
        return
    }

    $keepers = @($subfolders | Get-Random -Count $needed | ForEach-Object { $_.FullName })
    $others = @($subfolders | Where-Object { $keepers -notcontains $_.FullName } | ForEach-Object { $_.FullName })
    Write-LogInfo ("Consolidation: selected {0} keeper(s), {1} to drain." -f $keepers.Count, $others.Count)

    $liveCounts = @{}; $capacity = @{}
    foreach ($k in $keepers) {
        $c = if ($folderCounts.ContainsKey($k)) { [int]$folderCounts[$k] } else { 0 }
        $liveCounts[$k] = $c
        $capacity[$k] = [Math]::Max(0, $FilesPerFolderLimit - $c)
    }

    $filesToMove = @()
    foreach ($o in $others) {
        try { $filesToMove += (Get-ChildItem -LiteralPath $o -File -Force -ErrorAction Stop) } catch {
            Write-LogWarning "Consolidation: failed enumerating files in '$o': $($_.Exception.Message)"
            $WarningCount.Value++
        }
    }
    try { $filesToMove += (Get-ChildItem -LiteralPath $TargetFolder -File -Force -ErrorAction Stop) } catch {
        Write-LogDebug "Failed to enumerate files in target folder root: $_"
    }

    if (-not $filesToMove -or $filesToMove.Count -eq 0) {
        Write-LogInfo "Consolidation: nothing to move; proceeding to delete empty subfolders (if any)."
    } else {
        try { if ($filesToMove.Count -gt 1) { $filesToMove = $filesToMove | Get-Random -Count $filesToMove.Count } } catch {
            Write-LogDebug "Failed to shuffle files for consolidation: $_"
        }

        $totalMoves = $filesToMove.Count
        $GlobalFileCounter.Value = 0
        Write-LogInfo ("Consolidation: moving {0} file(s) into {1} keeper(s)..." -f $totalMoves, $keepers.Count)

        foreach ($file in $filesToMove) {
            $eligible = @()
            foreach ($k in $keepers) { if ($capacity[$k] -gt 0) { $eligible += $k } }
            if ($eligible.Count -eq 0) {
                $newK = Join-Path -Path $TargetFolder -ChildPath (Get-RandomFileName)
                try { New-Item -ItemType Directory -Path $newK -Force | Out-Null } catch {
                    Write-LogDebug "Failed to create new keeper directory ${newK}: $_"
                }
                $keepers += $newK
                $liveCounts[$newK] = 0
                $capacity[$newK] = $FilesPerFolderLimit
                $eligible = @($newK)
                Write-LogWarning "Consolidation: keeper capacity exhausted; created additional keeper '$newK'."
                $WarningCount.Value++
            }

            $minCount = ($eligible | ForEach-Object { $liveCounts[$_] } | Measure-Object -Minimum).Minimum
            $cands = @($eligible | Where-Object { $liveCounts[$_] -eq $minCount })
            $destFolder = if ($cands.Count -gt 1) { $cands | Get-Random } else { $cands[0] }

            $folderCount = if ($liveCounts.ContainsKey($destFolder)) { [int]$liveCounts[$destFolder] } else { 0 }
            $folderCountRef = New-Ref -Initial $folderCount
            $moveResult = Invoke-FileMove -SourceFilePath $file.FullName `
                -OriginalFileName $file.Name `
                -DestinationFolder $destFolder `
                -FolderCountRef $folderCountRef `
                -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete `
                -GlobalFileCounter $GlobalFileCounter `
                -ShowProgress:$ShowProgress `
                -UpdateFrequency $UpdateFrequency `
                -TotalFiles $totalMoves `
                -RetryDelay $RetryDelay `
                -RetryCount $RetryCount `
                -MaxBackoff $MaxBackoff `
                -ProgressActivity "Consolidating subfolders" `
                -ProgressStatusTemplate "Moved {0} of {1}" `
                -CopyFailureMessageTemplate "Consolidation: failed to copy '{0}' to '{1}'." `
                -PostCopyFailureMessageTemplate "Consolidation: post-copy handling failed for '{0}': {1}" `
                -WarningCount $WarningCount -ErrorCount $ErrorCount

            if ($moveResult.Success) {
                $liveCounts[$destFolder] = $folderCountRef.Value
                $capacity[$destFolder] = [Math]::Max(0, $FilesPerFolderLimit - $liveCounts[$destFolder])
            }
        }
        if ($ShowProgress) { Write-Progress -Activity "Consolidating subfolders" -Status "Complete" -Completed }
    }

    $deleted = 0; $skipped = 0
    foreach ($o in $others) {
        try {
            $entries = (Get-ChildItem -LiteralPath $o -Force -ErrorAction Stop | Measure-Object).Count
            if ($entries -eq 0) {
                Invoke-WithRetry -Operation { Remove-Item -LiteralPath $o -Force -ErrorAction Stop } `
                    -Description "Consolidation: delete empty subfolder '$o'" `
                    -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff -IgnoreFileNotFound
                Write-LogInfo "Consolidation: deleted empty subfolder '$o'."
                $deleted++
            } else {
                $skipped++
                Write-LogWarning "Consolidation: subfolder '$o' not empty after move; skipping deletion."
                $WarningCount.Value++
            }
        } catch {
            $skipped++
            Write-LogWarning "Consolidation: failed to delete subfolder '$o': $($_.Exception.Message)"
            $WarningCount.Value++
        }
    }
    Write-LogInfo ("Consolidation: removed {0} empty subfolder(s); {1} skipped." -f $deleted, $skipped)

    $finalCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -ne $finalCounts) {
        $finalFolderCount = @($finalCounts.Keys).Count
        $finalTotalFiles = [int](($finalCounts.Values | Measure-Object -Sum).Sum)
        $avgAfter = if ($finalFolderCount -gt 0) { [double]$finalTotalFiles / [double]$finalFolderCount } else { 0.0 }
        Write-DistributionSummary -FolderCounts $finalCounts -Average $avgAfter -Label "Consolidation: === FINAL DISTRIBUTION (verification) ==="
    }
}
