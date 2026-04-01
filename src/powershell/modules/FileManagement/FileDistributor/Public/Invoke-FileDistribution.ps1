# Invoke-FileDistribution.ps1 - Core file distribution algorithm (public module function)

function Invoke-FileDistribution {
    param (
        [string[]]$Files,
        [object[]]$Subfolders,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [int]$Limit,
        [switch]$ShowProgress,
        [int]$UpdateFrequency,
        [string]$DeleteMode,
        $FilesToDelete,  # FileQueue object (PSCustomObject) - reference type, no [ref] needed
        [ref]$GlobalFileCounter,
        [int]$TotalFiles,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60
    )

    $targetNormalized = [IO.Path]::GetFullPath($TargetRoot)
    $folderCounts = Get-SubfolderFileCounts -TargetFolder $TargetRoot -IncludeEmpty -FallbackSubfolders $Subfolders
    if ($null -eq $folderCounts) {
        return
    }
    $subfolderPaths = @($folderCounts.Keys)

    if ($Subfolders) {
        foreach ($candidate in $Subfolders) {
            $pathCandidate = if ($candidate -is [IO.FileSystemInfo]) { $candidate.FullName } else { [string]$candidate }
            if ([string]::IsNullOrWhiteSpace($pathCandidate)) { continue }

            $resolved = Resolve-SubfolderPath -Path $pathCandidate -TargetRoot $TargetRoot
            if (-not $resolved) { continue }
            if (-not (Test-Path -LiteralPath $resolved -PathType Container)) { continue }
            if (-not $folderCounts.ContainsKey($resolved)) {
                $folderCounts[$resolved] = 0
                $subfolderPaths += $resolved
            }
        }
    }

    $subfolderPaths = @($subfolderPaths | Select-Object -Unique)
    if ($subfolderPaths.Count -eq 0) {
        $emergency = Join-Path -Path $TargetRoot -ChildPath (Get-RandomFileName)
        New-Item -ItemType Directory -Path $emergency -Force | Out-Null
        $subfolderPaths = @($emergency)
        $folderCounts[$emergency] = 0
        Write-LogWarning ("Distribution: created emergency destination subfolder '{0}' (no valid candidates)." -f $emergency)
    }

    Write-LogDebug ("DEBUG: Eligible subfolders ({0}): {1}" -f $subfolderPaths.Count, ($subfolderPaths -join ', '))

    # --- Randomize processing order of files to reduce bias ---
    $filesToProcess = $Files
    try {
        if ($Files.Count -gt 1) { $filesToProcess = $Files | Get-Random -Count $Files.Count }
    }
    catch {
        $filesToProcess = $Files
        Write-LogWarning "Could not shuffle file list due to: $($_.Exception.Message). Proceeding without shuffle."
    }

    foreach ($file in $filesToProcess) {
        $filePath = if ($file -is [System.IO.FileSystemInfo]) { $file.FullName } else { [string]$file }
        $originalName = if ($file -is [System.IO.FileSystemInfo]) { $file.Name } else { [System.IO.Path]::GetFileName($filePath) }

        # Choose eligible targets (under limit) using weighted random selection
        $eligible = @()
        foreach ($p in $subfolderPaths) {
            if ($folderCounts[$p] -lt $Limit) { $eligible += $p }
        }
        if ($eligible.Count -eq 0) {
            $eligible = $subfolderPaths
            Write-LogWarning "All subfolders appear at/over limit ($Limit). Selecting among all subfolders (best effort)."
        }

        # Weighted random selection based on available capacity
        if ($eligible.Count -eq 1) {
            $destinationFolder = $eligible[0]
        }
        else {
            # Calculate weights based on available capacity (Limit - current count)
            $weights = @{}
            $totalWeight = 0
            foreach ($p in $eligible) {
                $availableCapacity = $Limit - $folderCounts[$p]
                $weight = [Math]::Max(1, $availableCapacity)  # Ensure minimum weight of 1
                $weights[$p] = $weight
                $totalWeight += $weight
            }

            # Select folder using weighted random selection
            $randomValue = Get-Random -Minimum 0 -Maximum $totalWeight
            $cumulativeWeight = 0
            $destinationFolder = $eligible[0]  # fallback
            foreach ($p in $eligible) {
                $cumulativeWeight += $weights[$p]
                if ($randomValue -lt $cumulativeWeight) {
                    $destinationFolder = $p
                    break
                }
            }
        }

        Write-LogDebug "DEBUG: Eligible count: $($eligible.Count), Selected: $destinationFolder (count: $($folderCounts[$destinationFolder]))"
        Write-LogInfo "Selected destination before resolve: '$destinationFolder'"

        # Last-mile guards (never root, always under TargetRoot, must exist)
        $destinationFolder = Resolve-SubfolderPath -Path $destinationFolder -TargetRoot $TargetRoot
        $destNormalized = if ($destinationFolder) { [IO.Path]::GetFullPath($destinationFolder) } else { $null }
        $targetNormalized = [IO.Path]::GetFullPath($TargetRoot)

        $isBad = (
            [string]::IsNullOrWhiteSpace($destNormalized) -or
            $destNormalized -match '^[A-Za-z]$' -or
            $destNormalized -match '^[A-Za-z]:$' -or
            -not [System.IO.Path]::IsPathRooted($destNormalized) -or
            (-not $destNormalized.StartsWith($targetNormalized, [System.StringComparison]::OrdinalIgnoreCase))
        )

        if ($destNormalized -eq $targetNormalized -or $isBad) {
            $safe = $subfolderPaths | Where-Object {
                $_ -ne $TargetRoot -and (Test-Path -LiteralPath $_ -PathType Container) -and `
                ([IO.Path]::GetFullPath($_)).StartsWith($targetNormalized, [System.StringComparison]::OrdinalIgnoreCase)
            }
            if ($safe.Count -gt 0) {
                $fallback = $safe | Get-Random
                if ($destNormalized -eq $targetNormalized) {
                    Write-LogWarning "Destination resolved to the target ROOT; selecting a subfolder instead: '$fallback'."
                }
                else {
                    $destDisplay = if ($destNormalized) { $destNormalized } else { '<null>' }
                    Write-LogWarning "Destination escaped target root ('$destDisplay'); forcing subfolder '$fallback'."
                }
                $destinationFolder = $fallback
            }
            else {
                $destinationFolder = Join-Path -Path $TargetRoot -ChildPath (Get-RandomFileName)
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
                $folderCounts[$destinationFolder] = 0
                Write-LogWarning "Created emergency destination subfolder '$destinationFolder' to avoid using target root."
            }
        }

        # Recompute normalized destination AFTER any fallback/emergency selection.
        # (Fixes null dereference when logging/inspecting $destNormalized.)
        $destNormalized = if ($destinationFolder) { [IO.Path]::GetFullPath($destinationFolder) } else { $null }

        if (-not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
            try {
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
                Write-LogInfo "Created missing destination folder: $destinationFolder"
            }
            catch {
                Write-LogError "Failed to ensure destination folder '$destinationFolder': $($_.Exception.Message)"
                continue
            }
        }

        # Single, consistent DEBUG line using normalized paths (null-safe)
        $rooted = if ($destNormalized) { [System.IO.Path]::IsPathRooted($destNormalized) } else { $false }
        $startsWithTarget = if ($destNormalized) { $destNormalized.StartsWith($targetNormalized, [System.StringComparison]::OrdinalIgnoreCase) } else { $false }
        Write-LogDebug ("DEBUG: destNormalized='{0}' targetRootNormalized='{1}' rooted={2} startsWithTarget={3}" -f $destNormalized, $targetNormalized, $rooted, $startsWithTarget)

        $folderCount = if ($folderCounts.ContainsKey($destinationFolder)) { [int]$folderCounts[$destinationFolder] } else { 0 }
        $folderCountRef = New-Ref -Initial $folderCount
        $moveResult = Invoke-FileMove -SourceFilePath $filePath `
            -OriginalFileName $originalName `
            -DestinationFolder $destinationFolder `
            -FolderCountRef $folderCountRef `
            -DeleteMode $DeleteMode `
            -FilesToDelete $FilesToDelete `
            -GlobalFileCounter $GlobalFileCounter `
            -ShowProgress:$ShowProgress `
            -UpdateFrequency $UpdateFrequency `
            -TotalFiles $TotalFiles `
            -RetryDelay $RetryDelay `
            -RetryCount $RetryCount `
            -MaxBackoff $MaxBackoff `
            -ProgressActivity "Distributing Files" `
            -ProgressStatusTemplate "Processed {0} of {1} files" `
            -CopyFailureMessageTemplate "Failed to copy '{0}' to '{1}'. Original file not moved." `
            -PostCopyFailureMessageTemplate "Failed to process file '{0}' after copying. Error: {1}"

        if ($moveResult.Success) {
            $destinationFile = $moveResult.DestinationFile
            Write-LogInfo "Assigning randomized destination name for '$filePath' -> '$destinationFile'."
            $folderCounts[$destinationFolder] = $folderCountRef.Value
            if ($DeleteMode -eq "RecycleBin") {
                Write-LogInfo "Copied from $file to $destinationFile and moved original to Recycle Bin."
            }
            elseif ($DeleteMode -eq "Immediate") {
                Write-LogInfo "Copied from $file to $destinationFile and immediately deleted original."
            }
            elseif ($DeleteMode -eq "EndOfScript") {
                if ($moveResult.QueueQueued -eq $true) {
                    Write-LogInfo "Copied from $file to $destinationFile. Original pending deletion at end of script."
                }
                else {
                    Write-LogWarning "Copied from $file to $destinationFile, but original could not be queued for end-of-script deletion."
                }
            }
        }
    }

    if ($ShowProgress) { Write-Progress -Activity "Distributing Files" -Status "Complete" -Completed }
    $completionMsg = "File distribution completed: Processed $($GlobalFileCounter.Value) of $TotalFiles files."
    Write-LogInfo $completionMsg
    Write-Host $completionMsg
}
