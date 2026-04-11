# Invoke-DistributionRandomize.ps1 - Randomize algorithm (public module function)

function Invoke-DistributionRandomize {
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

    Write-LogInfo "Randomize: redistributing ALL files randomly across all subfolders..."

    $currentCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -eq $currentCounts) { return }
    $subfolderPaths = @($currentCounts.Keys)
    $subfolders = @($subfolderPaths | ForEach-Object { [pscustomobject]@{ FullName = $_ } })

    if (-not $subfolders -or $subfolders.Count -eq 0) {
        Write-LogInfo "Randomize: no subfolders present; nothing to do."
        return
    }

    Write-LogInfo ("Randomize: enumerating files from {0} subfolder(s)..." -f $subfolders.Count)

    $allFiles = @()
    $totalFiles = 0

    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        try {
            $files = @(Get-ChildItem -LiteralPath $p -File -Force -ErrorAction Stop)
            $allFiles += $files
            $totalFiles += $files.Count
            Write-LogDebug ("DEBUG: Folder '{0}' contains {1} file(s)" -f (Split-Path -Leaf $p), $files.Count)
        } catch {
            Write-LogWarning "Randomize: failed to enumerate files in '$p': $($_.Exception.Message)"
            $WarningCount.Value++
        }
    }

    if ($totalFiles -le 0) {
        Write-LogInfo "Randomize: no files to redistribute."
        return
    }

    Write-LogInfo ("Randomize: found {0} file(s) total across {1} subfolder(s)" -f $totalFiles, $subfolders.Count)

    $avg = [double]$totalFiles / [double]$subfolders.Count
    Write-DistributionSummary -FolderCounts $currentCounts -Average $avg -Label "Randomize: === CURRENT DISTRIBUTION ==="
    Write-LogInfo ("Randomize: average = {0:N2} files per folder" -f $avg)

    Write-LogInfo "Randomize: shuffling file list randomly..."
    try {
        if ($allFiles.Count -gt 1) {
            $allFiles = $allFiles | Get-Random -Count $allFiles.Count
            Write-LogInfo "Randomize: shuffle complete"
        }
    } catch {
        Write-LogWarning "Randomize: failed to shuffle files: $($_.Exception.Message). Proceeding without shuffle."
        $WarningCount.Value++
    }

    $targetPerFolder = [int][Math]::Ceiling([double]$totalFiles / [double]$subfolders.Count)
    Write-LogInfo ("Randomize: target = {0} files per folder (ceiling of {1} total / {2} folders)" -f $targetPerFolder, $totalFiles, $subfolders.Count)

    Write-LogInfo "Randomize: assigning files to folders using round-robin through shuffled list..."
    $assignments = @{}
    foreach ($sf in $subfolders) {
        $assignments[$sf.FullName] = [System.Collections.Generic.List[object]]::new()
    }

    $folderIndex = 0
    $subfolderPaths = @($subfolders | ForEach-Object { $_.FullName })
    $fileToFolder = @{}

    foreach ($file in $allFiles) {
        $targetFolderPath = $subfolderPaths[$folderIndex]
        $assignments[$targetFolderPath].Add($file)
        $fileToFolder[$file] = $targetFolderPath
        $folderIndex = ($folderIndex + 1) % $subfolderPaths.Count
    }

    Write-LogInfo "Randomize: === PLANNED DISTRIBUTION ==="
    foreach ($sf in ($subfolders | Sort-Object { $assignments[$_.FullName].Count } -Descending)) {
        $p = $sf.FullName
        $plannedCount = $assignments[$p].Count
        $currentCount = $currentCounts[$p]
        $delta = $plannedCount - $currentCount
        $folderName = Split-Path -Leaf $p
        Write-LogInfo ("  {0}: {1} files (currently {2}, {3:+0;-0;0})" -f $folderName, $plannedCount, $currentCount, $delta)
    }

    $filesStaying = 0
    $filesMoving = 0
    foreach ($file in $allFiles) {
        $currentFolder = Split-Path -Path $file.FullName -Parent
        $assignedFolder = $fileToFolder[$file]
        if ($currentFolder -eq $assignedFolder) {
            $filesStaying++
        } else {
            $filesMoving++
        }
    }

    $stayingPct = if ($totalFiles -gt 0) { ($filesStaying / $totalFiles) * 100 } else { 0 }
    $movingPct = if ($totalFiles -gt 0) { ($filesMoving / $totalFiles) * 100 } else { 0 }

    Write-LogInfo "Randomize: === MOVE STATISTICS ==="
    Write-LogInfo ("  Files staying in current folder: {0} ({1:N1}%)" -f $filesStaying, $stayingPct)
    Write-LogInfo ("  Files moving to different folder: {0} ({1:N1}%)" -f $filesMoving, $movingPct)
    Write-LogInfo ("Randomize: beginning file redistribution ({0} files to move)..." -f $filesMoving)

    $GlobalFileCounter.Value = 0
    $totalMoves = 0
    $totalSkipped = 0
    $totalErrors = 0
    $lastLoggedProgress = 0
    $threshold = if ($filesMoving -gt 0) { [Math]::Max(1, [int]($filesMoving / 10)) } else { [int]::MaxValue }

    foreach ($destFolder in $subfolderPaths) {
        $filesToMove = $assignments[$destFolder]
        if ($filesToMove.Count -eq 0) { continue }

        $destFolderName = Split-Path -Leaf $destFolder
        Write-LogDebug ("DEBUG: Processing {0} file(s) assigned to folder '{1}'" -f $filesToMove.Count, $destFolderName)

        foreach ($file in $filesToMove) {
            $currentFolder = Split-Path -Path $file.FullName -Parent
            if ($currentFolder -eq $destFolder) {
                $totalSkipped++
                Write-LogDebug ("DEBUG: Skipping '{0}' - already in assigned folder" -f $file.Name)
                continue
            }

            Write-LogDebug ("DEBUG: Moving '{0}' from '{1}' to '{2}'" -f $file.Name, (Split-Path -Leaf $currentFolder), $destFolderName)

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
                -TotalFiles $filesMoving `
                -RetryDelay $RetryDelay `
                -RetryCount $RetryCount `
                -MaxBackoff $MaxBackoff `
                -ProgressActivity "Randomizing distribution" `
                -ProgressStatusTemplate "Moved {0} of {1} files" `
                -CopyFailureMessageTemplate "Randomize: failed to copy '{0}' to '{1}'." `
                -PostCopyFailureMessageTemplate "Randomize: failed to handle original file '{0}': {1}" `
                -CopyFailureIsWarning `
                -IncrementOnSuccessOnly `
                -WarningCount $WarningCount -ErrorCount $ErrorCount

            if ($moveResult.Success) {
                $totalMoves++

                if ($GlobalFileCounter.Value - $lastLoggedProgress -ge $threshold) {
                    $pct = if ($filesMoving -gt 0) { ($GlobalFileCounter.Value / $filesMoving) * 100 } else { 0 }
                    Write-LogInfo ("Randomize: progress - moved {0}/{1} files ({2:N1}%)" -f $GlobalFileCounter.Value, $filesMoving, $pct)
                    $lastLoggedProgress = $GlobalFileCounter.Value
                }
            } else {
                $totalErrors++
            }
        }
    }

    if ($ShowProgress) { Write-Progress -Activity "Randomizing distribution" -Status "Complete" -Completed }

    Write-LogInfo "Randomize: === FINAL RESULTS ==="
    Write-LogInfo ("  Files moved successfully: {0}" -f $totalMoves)
    Write-LogInfo ("  Files skipped (already in assigned folder): {0}" -f $totalSkipped)
    if ($totalErrors -gt 0) {
        Write-LogWarning ("  Files failed to move: {0}" -f $totalErrors)
        $WarningCount.Value++
    }
    Write-LogInfo ("Randomize: redistribution complete - moved {0} file(s) to achieve random even distribution" -f $totalMoves)

    $finalCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -ne $finalCounts) {
        Write-DistributionSummary -FolderCounts $finalCounts -Average $avg -Label "Randomize: === FINAL DISTRIBUTION (verification) ==="
    }
}
