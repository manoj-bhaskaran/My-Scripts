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

    LogMessage -Message "Randomize: redistributing ALL files randomly across all subfolders..."

    $currentCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -eq $currentCounts) { return }
    $subfolderPaths = @($currentCounts.Keys)
    $subfolders = @($subfolderPaths | ForEach-Object { [pscustomobject]@{ FullName = $_ } })

    if (-not $subfolders -or $subfolders.Count -eq 0) {
        LogMessage -Message "Randomize: no subfolders present; nothing to do." -ConsoleOutput
        return
    }

    LogMessage -Message ("Randomize: enumerating files from {0} subfolder(s)..." -f $subfolders.Count)

    $allFiles = @()
    $totalFiles = 0

    foreach ($sf in $subfolders) {
        $p = $sf.FullName
        try {
            $files = @(Get-ChildItem -LiteralPath $p -File -Force -ErrorAction Stop)
            $allFiles += $files
            $totalFiles += $files.Count
            LogMessage -Message ("DEBUG: Folder '{0}' contains {1} file(s)" -f (Split-Path -Leaf $p), $files.Count) -IsDebug
        } catch {
            LogMessage -Message "Randomize: failed to enumerate files in '$p': $($_.Exception.Message)" -IsWarning
        }
    }

    if ($totalFiles -le 0) {
        LogMessage -Message "Randomize: no files to redistribute." -ConsoleOutput
        return
    }

    LogMessage -Message ("Randomize: found {0} file(s) total across {1} subfolder(s)" -f $totalFiles, $subfolders.Count)

    $avg = [double]$totalFiles / [double]$subfolders.Count
    Write-DistributionSummary -FolderCounts $currentCounts -Average $avg -Label "Randomize: === CURRENT DISTRIBUTION ==="
    LogMessage -Message ("Randomize: average = {0:N2} files per folder" -f $avg)

    LogMessage -Message "Randomize: shuffling file list randomly..."
    try {
        if ($allFiles.Count -gt 1) {
            $allFiles = $allFiles | Get-Random -Count $allFiles.Count
            LogMessage -Message "Randomize: shuffle complete"
        }
    } catch {
        LogMessage -Message "Randomize: failed to shuffle files: $($_.Exception.Message). Proceeding without shuffle." -IsWarning
    }

    $targetPerFolder = [int][Math]::Ceiling([double]$totalFiles / [double]$subfolders.Count)
    LogMessage -Message ("Randomize: target = {0} files per folder (ceiling of {1} total / {2} folders)" -f $targetPerFolder, $totalFiles, $subfolders.Count)

    LogMessage -Message "Randomize: assigning files to folders using round-robin through shuffled list..."
    $assignments = @{}
    foreach ($sf in $subfolders) {
        $assignments[$sf.FullName] = @()
    }

    $folderIndex = 0
    $subfolderPaths = @($subfolders | ForEach-Object { $_.FullName })

    foreach ($file in $allFiles) {
        $targetFolderPath = $subfolderPaths[$folderIndex]
        $assignments[$targetFolderPath] += $file
        $folderIndex = ($folderIndex + 1) % $subfolderPaths.Count
    }

    LogMessage -Message "Randomize: === PLANNED DISTRIBUTION ==="
    foreach ($sf in ($subfolders | Sort-Object { $assignments[$_.FullName].Count } -Descending)) {
        $p = $sf.FullName
        $plannedCount = $assignments[$p].Count
        $currentCount = $currentCounts[$p]
        $delta = $plannedCount - $currentCount
        $folderName = Split-Path -Leaf $p
        LogMessage -Message ("  {0}: {1} files (currently {2}, {3:+0;-0;0})" -f $folderName, $plannedCount, $currentCount, $delta)
    }

    $filesStaying = 0
    $filesMoving = 0
    foreach ($file in $allFiles) {
        $currentFolder = Split-Path -Path $file.FullName -Parent
        $assignedFolder = $null
        foreach ($p in $subfolderPaths) {
            if ($assignments[$p] -contains $file) {
                $assignedFolder = $p
                break
            }
        }
        if ($currentFolder -eq $assignedFolder) {
            $filesStaying++
        } else {
            $filesMoving++
        }
    }

    $stayingPct = if ($totalFiles -gt 0) { ($filesStaying / $totalFiles) * 100 } else { 0 }
    $movingPct = if ($totalFiles -gt 0) { ($filesMoving / $totalFiles) * 100 } else { 0 }

    LogMessage -Message "Randomize: === MOVE STATISTICS ==="
    LogMessage -Message ("  Files staying in current folder: {0} ({1:N1}%)" -f $filesStaying, $stayingPct)
    LogMessage -Message ("  Files moving to different folder: {0} ({1:N1}%)" -f $filesMoving, $movingPct)
    LogMessage -Message ("Randomize: beginning file redistribution ({0} files to move)..." -f $filesMoving)

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
        LogMessage -Message ("DEBUG: Processing {0} file(s) assigned to folder '{1}'" -f $filesToMove.Count, $destFolderName) -IsDebug

        foreach ($file in $filesToMove) {
            $currentFolder = Split-Path -Path $file.FullName -Parent
            if ($currentFolder -eq $destFolder) {
                $totalSkipped++
                LogMessage -Message ("DEBUG: Skipping '{0}' - already in assigned folder" -f $file.Name) -IsDebug
                continue
            }

            LogMessage -Message ("DEBUG: Moving '{0}' from '{1}' to '{2}'" -f $file.Name, (Split-Path -Leaf $currentFolder), $destFolderName) -IsDebug

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
                    LogMessage -Message ("Randomize: progress - moved {0}/{1} files ({2:N1}%)" -f $GlobalFileCounter.Value, $filesMoving, $pct)
                    $lastLoggedProgress = $GlobalFileCounter.Value
                }
            } else {
                $totalErrors++
            }
        }
    }

    if ($ShowProgress) { Write-Progress -Activity "Randomizing distribution" -Status "Complete" -Completed }

    LogMessage -Message "Randomize: === FINAL RESULTS ==="
    LogMessage -Message ("  Files moved successfully: {0}" -f $totalMoves)
    LogMessage -Message ("  Files skipped (already in assigned folder): {0}" -f $totalSkipped)
    if ($totalErrors -gt 0) {
        LogMessage -Message ("  Files failed to move: {0}" -f $totalErrors) -IsWarning
    }
    LogMessage -Message ("Randomize: redistribution complete - moved {0} file(s) to achieve random even distribution" -f $totalMoves)

    $finalCounts = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty
    if ($null -ne $finalCounts) {
        Write-DistributionSummary -FolderCounts $finalCounts -Average $avg -Label "Randomize: === FINAL DISTRIBUTION (verification) ==="
    }
}
