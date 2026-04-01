# Invoke-FolderRebalance.ps1 - Rebalance algorithm (public module function)

function Invoke-FolderRebalance {
    param (
        [Parameter(Mandatory = $true)][string]$TargetFolder,
        [Parameter(Mandatory = $true)][int]$FilesPerFolderLimit,
        [int]$Tolerance = 10,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)]$FilesToDelete,
        [Parameter(Mandatory = $true)][ref]$GlobalFileCounter,
        [Parameter(Mandatory = $true)][ref]$WarningCount,
        [Parameter(Mandatory = $true)][ref]$ErrorCount,
        [Parameter(Mandatory = $true)][int]$RetryDelay,
        [Parameter(Mandatory = $true)][int]$RetryCount
    )

    # Calculate tolerance multipliers
    $toleranceDecimal = [double]$Tolerance / 100.0
    $lowerMultiplier = 1.0 - $toleranceDecimal
    $upperMultiplier = 1.0 + $toleranceDecimal

    LogMessage -Message ("Rebalance: computing average and deviation thresholds (±{0}%)..." -f $Tolerance)

    $folderCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -eq $folderCounts) { return }
    $subfolderPaths = @($folderCounts.Keys)
    $subfolders = @($subfolderPaths | ForEach-Object { [pscustomobject]@{ FullName = $_ } })
    $totalFiles = [int](($folderCounts.Values | Measure-Object -Sum).Sum)

    if (-not $subfolders -or $subfolders.Count -le 1) {
        LogMessage -Message "Rebalance: need at least two subfolders. Nothing to do." -ConsoleOutput
        return
    }

    LogMessage -Message ("Rebalance: enumerating files from {0} subfolder(s)..." -f $subfolders.Count)
    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        LogMessage -Message ("DEBUG: Folder '{0}' contains {1} file(s)" -f (Split-Path -Leaf $p), $folderCounts[$p]) -IsDebug
    }

    if ($totalFiles -le 0) {
        LogMessage -Message "Rebalance: no files to rebalance." -ConsoleOutput
        return
    }

    $avg = [double]$totalFiles / [double]$subfolders.Count
    $low = [int][math]::Floor($avg * $lowerMultiplier)
    $high = [int][math]::Ceiling($avg * $upperMultiplier)

    LogMessage -Message ("Rebalance: totalFiles={0}, subfolders={1}, avg={2:N2}, lowerBound={3}, upperBound={4} (limit={5}, tolerance=±{6}%)" -f $totalFiles, $subfolders.Count, $avg, $low, $high, $FilesPerFolderLimit, $Tolerance)

    Write-DistributionSummary -FolderCounts $folderCounts -Average $avg -Label "Rebalance: === CURRENT DISTRIBUTION ===" -UpperBound $high -LowerBound $low

    # Classify donors and receivers
    $donors = @()
    $receivers = @()
    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        $c = [int]$folderCounts[$p]
        $surplus = $c - $high
        $deficit = $low - $c
        if ($surplus -gt 0) {
            $donors += [pscustomobject]@{ Path = $p; Surplus = $surplus }
        } elseif ($deficit -gt 0) {
            $receivers += [pscustomobject]@{ Path = $p; Deficit = $deficit }
        }
    }

    if (-not $donors -and -not $receivers) {
        LogMessage -Message ("Rebalance: all subfolders already within ±{0}% of average. Nothing to do." -f $Tolerance) -ConsoleOutput
        return
    }
    if (-not $receivers) {
        LogMessage -Message "Rebalance: no receivers below lower bound; cannot reduce above-average folders without capacity. Nothing to do." -ConsoleOutput
        return
    }

    $totalSurplus = ($donors   | Measure-Object -Property Surplus -Sum).Sum
    $totalDeficit = ($receivers | Measure-Object -Property Deficit -Sum).Sum
    $plannedMoves = [int][Math]::Min([int]$totalSurplus, [int]$totalDeficit)

    LogMessage -Message ("Rebalance: donors={0} (surplus={1}), receivers={2} (deficit={3}), plannedMoves={4}" -f $donors.Count, $totalSurplus, $receivers.Count, $totalDeficit, $plannedMoves)

    if ($donors.Count -gt 0) {
        LogMessage -Message "Rebalance: === DONORS (above upper bound) ==="
        foreach ($d in ($donors | Sort-Object -Property Surplus -Descending)) {
            $folderName = Split-Path -Leaf $d.Path
            $currentCount = $folderCounts[$d.Path]
            LogMessage -Message ("  {0}: {1} files (surplus: {2})" -f $folderName, $currentCount, $d.Surplus)
        }
    }

    if ($receivers.Count -gt 0) {
        LogMessage -Message "Rebalance: === RECEIVERS (below lower bound) ==="
        foreach ($r in ($receivers | Sort-Object -Property Deficit -Descending)) {
            $folderName = Split-Path -Leaf $r.Path
            $currentCount = $folderCounts[$r.Path]
            LogMessage -Message ("  {0}: {1} files (deficit: {2})" -f $folderName, $currentCount, $r.Deficit)
        }
    }

    LogMessage -Message ("Rebalance: beginning file transfers ({0} files to move)..." -f $plannedMoves)

    if ($plannedMoves -le 0) {
        LogMessage -Message "Rebalance: no feasible moves. Nothing to do." -ConsoleOutput
        return
    }

    $donors = $donors | Sort-Object -Property Surplus -Descending
    $receiverMap = @{}
    foreach ($r in $receivers) { $receiverMap[$r.Path] = [int]$r.Deficit }

    function Get-BestReceiver([hashtable]$map) {
        if ($map.Keys.Count -eq 0) { return $null }
        $bestKey = $null; $bestVal = -1
        foreach ($k in $map.Keys) {
            $v = [int]$map[$k]
            if ($v -gt $bestVal) { $bestVal = $v; $bestKey = $k }
        }
        if ($bestVal -le 0) { return $null }
        return $bestKey
    }

    $GlobalFileCounter.Value = 0
    $totalMoved = 0
    $totalFailed = 0
    $lastLoggedProgress = 0

    foreach ($d in $donors) {
        if ($GlobalFileCounter.Value -ge $plannedMoves) { break }
        $src = $d.Path
        $srcFolderName = Split-Path -Leaf $src
        $moveCount = [int][Math]::Min([int]$d.Surplus, [int]($plannedMoves - $GlobalFileCounter.Value))
        if ($moveCount -le 0) { continue }

        $candidates = @()
        try {
            $allFiles = Get-ChildItem -LiteralPath $src -File -Force -ErrorAction Stop
            if ($allFiles.Count -gt 0) {
                $moveCount = [Math]::Min($moveCount, $allFiles.Count)
                $candidates = if ($moveCount -lt $allFiles.Count) { $allFiles | Get-Random -Count $moveCount } else { $allFiles }
                LogMessage -Message ("DEBUG: Selected {0} file(s) from donor '{1}'" -f $candidates.Count, $srcFolderName) -IsDebug
            }
        } catch {
            LogMessage -Message "Rebalance: failed to enumerate files in donor '$src': $($_.Exception.Message)" -IsWarning
            continue
        }
        if (-not $candidates) { continue }

        foreach ($file in $candidates) {
            if ($GlobalFileCounter.Value -ge $plannedMoves) { break }
            $destFolder = Get-BestReceiver $receiverMap
            if (-not $destFolder) { break }

            $destFolderName = Split-Path -Leaf $destFolder

            LogMessage -Message ("DEBUG: Moving '{0}' from '{1}' to '{2}'" -f $file.Name, $srcFolderName, $destFolderName) -IsDebug

            $folderCountRef = New-Ref -Initial 0
            $moveResult = Invoke-FileMove -SourceFilePath $file.FullName `
                -OriginalFileName $file.Name `
                -DestinationFolder $destFolder `
                -FolderCountRef $folderCountRef `
                -DeleteMode $DeleteMode `
                -FilesToDelete $FilesToDelete `
                -GlobalFileCounter $GlobalFileCounter `
                -ShowProgress:$ShowProgress `
                -UpdateFrequency $UpdateFrequency `
                -TotalFiles $plannedMoves `
                -RetryDelay $RetryDelay `
                -RetryCount $RetryCount `
                -ProgressActivity "Rebalancing subfolders" `
                -ProgressStatusTemplate "Moved {0} of {1}" `
                -CopyFailureMessageTemplate "Rebalance: failed to copy '{0}' to '{1}'." `
                -PostCopyFailureMessageTemplate "Rebalance: post-copy handling failed for '{0}': {1}" `
                -IncrementOnSuccessOnly `
                -WarningCount $WarningCount -ErrorCount $ErrorCount

            if ($moveResult.Success) {
                $receiverMap[$destFolder] = [Math]::Max(0, ([int]$receiverMap[$destFolder]) - 1)
                if ($receiverMap[$destFolder] -le 0) { $receiverMap.Remove($destFolder) }
                $totalMoved++

                if ($GlobalFileCounter.Value - $lastLoggedProgress -ge ($plannedMoves / 10)) {
                    $pct = if ($plannedMoves -gt 0) { ($GlobalFileCounter.Value / $plannedMoves) * 100 } else { 0 }
                    LogMessage -Message ("Rebalance: progress - moved {0}/{1} files ({2:N1}%)" -f $GlobalFileCounter.Value, $plannedMoves, $pct)
                    $lastLoggedProgress = $GlobalFileCounter.Value
                }
            } else {
                $totalFailed++
            }
        }
    }

    if ($ShowProgress) { Write-Progress -Activity "Rebalancing subfolders" -Status "Complete" -Completed }

    LogMessage -Message "Rebalance: === FINAL RESULTS ==="
    LogMessage -Message ("  Files moved successfully: {0}" -f $totalMoved)
    if ($totalFailed -gt 0) {
        LogMessage -Message ("  Files failed to move: {0}" -f $totalFailed) -IsWarning
    }
    LogMessage -Message ("Rebalance: redistribution complete - moved {0} of {1} planned file(s)" -f $totalMoved, $plannedMoves)

    $finalCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -ne $finalCounts) {
        Write-DistributionSummary -FolderCounts $finalCounts -Average $avg -Label "Rebalance: === FINAL DISTRIBUTION (verification) ===" -UpperBound $high -LowerBound $low
    }
}
