# Invoke-TargetRedistribution.ps1 - Target-folder redistribution algorithm (public module function)

function Invoke-TargetRedistribution {
    param (
        [string]$TargetFolder,
        [object[]]$Subfolders,
        [int]$FilesPerFolderLimit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency,
        [string]$DeleteMode,
        $FilesToDelete,  # FileQueue object (PSCustomObject) - reference type, no [ref] needed
        [ref]$GlobalFileCounter,
        [int]$TotalFiles,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60,
        [ref]$WarningCount,
        [ref]$ErrorCount
    )

    $folderFilesMap = Get-SubfolderFileCounts -TargetFolder $TargetFolder -IncludeEmpty -FallbackSubfolders $Subfolders
    if ($null -eq $folderFilesMap) {
        return
    }
    $normalizedSubfolders = @($folderFilesMap.Keys)

    Write-LogDebug ("DEBUG: Normalized subfolders for redistribution ({0} items): {1}" -f $normalizedSubfolders.Count, ($normalizedSubfolders -join ', '))

    if ($normalizedSubfolders.Count -eq 0) {
        Write-LogWarning "No valid subfolders available for redistribution. Creating emergency subfolder."
        if ($WarningCount) { $WarningCount.Value++ }
        $randomName = Get-RandomFileName
        $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
        New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
        $normalizedSubfolders = @($newFolder)
        $folderFilesMap[$newFolder] = 0
    }

    # Step 2: Redistribute files from root of target folder (not subfolders)
    Write-LogInfo "Redistributing files from target folder $TargetFolder to subfolders..."
    $rootFiles = Get-ChildItem -LiteralPath $TargetFolder -File -ErrorAction Stop
    $redistributionTotal = 0
    $redistributionProcessed = 0

    if ($rootFiles.Count -gt 0) {
        # Use the already normalized subfolders directly
        if ($normalizedSubfolders.Count -eq 0) {
            # Create a new subfolder if none exist
            $randomName = Get-RandomFileName
            $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
            New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
            Write-LogInfo "Created new target subfolder: $newFolder for redistribution from root folder."
            $normalizedSubfolders = @($newFolder)
        }

        # Reset phase counter and compute correct denominator
        $GlobalFileCounter.Value = 0
        $redistributionTotal += $rootFiles.Count

        Write-LogDebug ("DEBUG (redistribute-root) candidates={0}" -f ($normalizedSubfolders -join '; '))

        Invoke-FileDistribution -Files $rootFiles `
            -Subfolders $normalizedSubfolders `
            -TargetRoot $TargetFolder `
            -Limit $FilesPerFolderLimit `
            -ShowProgress:$ShowProgress `
            -UpdateFrequency:$UpdateFrequency `
            -DeleteMode $DeleteMode `
            -FilesToDelete $FilesToDelete `
            -GlobalFileCounter $GlobalFileCounter `
            -TotalFiles $rootFiles.Count `
            -RetryDelay $RetryDelay `
            -RetryCount $RetryCount `
            -MaxBackoff $MaxBackoff `
            -WarningCount $WarningCount `
            -ErrorCount $ErrorCount
        $redistributionProcessed += $GlobalFileCounter.Value
    }

    # Step 3: Identify overloaded folders and select random files for redistribution
    $filesToRedistributeMap = @{}

    foreach ($folder in $folderFilesMap.Keys) {
        $fileCount = $folderFilesMap[$folder]
        if ($fileCount -gt $FilesPerFolderLimit) {
            $excess = $fileCount - $FilesPerFolderLimit
            $allFolderFiles = @(Get-ChildItem -Path $folder -File)
            $safeExcess = [Math]::Min($excess, $allFolderFiles.Count)
            $overloadedFiles = if ($safeExcess -lt $allFolderFiles.Count) {
                $allFolderFiles | Get-Random -Count $safeExcess
            } else {
                $allFolderFiles
            }
            $filesToRedistributeMap[$folder] = $overloadedFiles
            Write-LogInfo "Folder $folder is overloaded by $excess file(s), queuing for redistribution."
            $redistributionTotal += $overloadedFiles.Count
        }
    }

    # Step 4: Redistribute files from overloaded folders, excluding the source folder from targets
    foreach ($sourceFolder in $filesToRedistributeMap.Keys) {
        $sourceFiles = $filesToRedistributeMap[$sourceFolder]

        $eligibleTargets = $folderFilesMap.GetEnumerator() |
            Where-Object {
                $_.Key -ne $TargetFolder -and $_.Key -ne $sourceFolder -and $_.Value -lt $FilesPerFolderLimit
            } |
            ForEach-Object { $_.Key } |
            Select-Object -Unique

        if ($eligibleTargets.Count -eq 0) {
            # Create a new subfolder using Get-RandomFileName
            $randomName = Get-RandomFileName
            $newFolder = Join-Path -Path $TargetFolder -ChildPath $randomName
            New-Item -Path $newFolder -ItemType Directory -Force | Out-Null
            Write-LogInfo "Created new target subfolder: $newFolder for redistribution from overloaded folder $sourceFolder."

            # Update maps
            $eligibleTargets = @($newFolder)
            $Subfolders += (Get-Item -LiteralPath $newFolder)
            $folderFilesMap[$newFolder] = 0
        }

        # Reset phase counter and use per-batch denominator
        Write-LogDebug ("DEBUG (redistribute-overload from '{0}') candidates={1}" -f `
                $sourceFolder, ($eligibleTargets -join '; '))

        $GlobalFileCounter.Value = 0
        Invoke-FileDistribution -Files $sourceFiles `
            -Subfolders $eligibleTargets `
            -TargetRoot $TargetFolder `
            -Limit $FilesPerFolderLimit `
            -ShowProgress:$ShowProgress `
            -UpdateFrequency:$UpdateFrequency `
            -DeleteMode $DeleteMode `
            -FilesToDelete $FilesToDelete `
            -GlobalFileCounter $GlobalFileCounter `
            -TotalFiles $sourceFiles.Count `
            -RetryDelay $RetryDelay `
            -RetryCount $RetryCount `
            -MaxBackoff $MaxBackoff `
            -WarningCount $WarningCount `
            -ErrorCount $ErrorCount
        $redistributionProcessed += $GlobalFileCounter.Value
    }

    Write-LogInfo "File redistribution completed: Processed $redistributionProcessed of $redistributionTotal files in the target folder."
}
