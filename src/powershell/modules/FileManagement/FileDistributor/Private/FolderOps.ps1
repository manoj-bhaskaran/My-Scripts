# (randomname.ps1 will be resolved and loaded inside Main via Initialize-RandomNameGenerator)

function Resolve-DistributionFileName {
    param (
        [string]$TargetFolder,
        [string]$OriginalFileName
    )

    # Get the extension of the original file
    $extension = [System.IO.Path]::GetExtension($OriginalFileName)

    # Loop to generate a unique file name
    do {
        $newFileName = (Get-RandomFileName) + $extension
        $newFilePath = Join-Path -Path $TargetFolder -ChildPath $newFileName
    } while (Test-Path -Path $newFilePath)

    return $newFileName
}

function New-DistributionSubfolders {
    param (
        [string]$TargetPath,
        [int]$NumberOfFolders,
        [switch]$ShowProgress,
        [int]$UpdateFrequency
    )

    # Initialize an array to store created folder paths
    $createdFolders = @()

    for ($i = 1; $i -le $NumberOfFolders; $i++) {
        do {
            # Generate a random folder name
            $randomFolderName = Get-RandomFileName
            $folderPath = Join-Path -Path $TargetPath -ChildPath $randomFolderName
        } while (Test-Path -Path $folderPath)

        # Create the new directory and keep a DirectoryInfo so we retain FullName later
        $dirInfo = New-Item -ItemType Directory -Path $folderPath -Force
        $createdFolders += $dirInfo

        # Log the creation of the folder
        Write-LogInfo "Created folder: $folderPath"

        # Show progress if enabled
        if ($ShowProgress -and ($i % $UpdateFrequency -eq 0)) {
            $percentComplete = [math]::Floor(($i / $NumberOfFolders) * 100)
            Write-Progress -Activity "Creating Subfolders" `
                -Status "Created $i of $NumberOfFolders folders" `
                -PercentComplete $percentComplete
        }
    }

    # Final progress message
    if ($ShowProgress) {
        Write-Progress -Activity "Creating Subfolders" -Status "Complete" -Completed
    }

    return $createdFolders
}

# NOTE: Move-ToRecycleBin uses Shell.Application COM object (namespace 10) — Windows-only.
function Move-ToRecycleBin {
    param (
        [string]$FilePath,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60
    )

    try {
        # Create a new Shell.Application COM object
        $shell = New-Object -ComObject Shell.Application

        # 10 is the folder type for Recycle Bin
        $recycleBin = $shell.NameSpace(10)

        # Get the file to be moved to the Recycle Bin
        $file = Get-Item $FilePath

        # Move the file to the Recycle Bin with retry, suppressing confirmation (0x100)
        Invoke-WithRetry -Operation { $recycleBin.MoveHere($file.FullName, 0x100) } -MaxBackoff $MaxBackoff `
            -Description "Recycle '$($file.FullName)'" `
            -RetryDelay $RetryDelay -RetryCount $RetryCount

        # Log success
        Write-LogInfo "Moved $FilePath to Recycle Bin."
    }
    catch {
        # Log failure
        Write-LogWarning "Failed to move $FilePath to Recycle Bin. Error: $($_.Exception.Message)"
    }
}

function Remove-DistributionFile {
    param (
        [string]$FilePath,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3
    )

    try {
        # Check if the file exists before attempting deletion
        if (Test-Path -Path $FilePath) {
            Remove-ItemWithRetry -Path $FilePath -RetryDelay $RetryDelay -RetryCount $RetryCount
            Write-LogInfo "Deleted file: $FilePath."
        }
        else {
            Write-LogWarning "File $FilePath not found. Skipping deletion."
        }
    }
    catch {
        # Log failure
        Write-LogWarning "Failed to delete file $FilePath. Error: $($_.Exception.Message)"
    }
}

function Invoke-FileMove {
    param (
        [Parameter(Mandatory = $true)][string]$SourceFilePath,
        [Parameter(Mandatory = $true)][string]$OriginalFileName,
        [Parameter(Mandatory = $true)][string]$DestinationFolder,
        [Parameter(Mandatory = $true)][ref]$FolderCountRef,
        [Parameter(Mandatory = $true)][string]$DeleteMode,
        [Parameter(Mandatory = $true)]$FilesToDelete,
        [Parameter(Mandatory = $true)][ref]$GlobalFileCounter,
        [switch]$ShowProgress,
        [int]$UpdateFrequency = 100,
        [int]$TotalFiles = 0,
        [int]$RetryDelay = 5,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60,
        [string]$ProgressActivity = "Distributing Files",
        [string]$ProgressStatusTemplate = "Processed {0} of {1} files",
        [string]$CopyFailureMessageTemplate = "Failed to copy '{0}' to '{1}'.",
        [string]$PostCopyFailureMessageTemplate = "Post-copy handling failed for '{0}': {1}",
        [switch]$CopyFailureIsWarning,
        [switch]$IncrementOnSuccessOnly
    )

    $newFileName = Resolve-DistributionFileName -TargetFolder $DestinationFolder -OriginalFileName $OriginalFileName
    $destinationFile = Join-Path -Path $DestinationFolder -ChildPath $newFileName

    Copy-ItemWithRetry -Path $SourceFilePath -Destination $destinationFile -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff

    $copySucceeded = Test-Path -LiteralPath $destinationFile
    $queuedForEndOfScriptDeletion = $null
    if ($copySucceeded) {
        $FolderCountRef.Value++
        try {
            if ($DeleteMode -eq "RecycleBin") {
                Move-ToRecycleBin -FilePath $SourceFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount -MaxBackoff $MaxBackoff
            }
            elseif ($DeleteMode -eq "Immediate") {
                Remove-DistributionFile -FilePath $SourceFilePath -RetryDelay $RetryDelay -RetryCount $RetryCount
            }
            elseif ($DeleteMode -eq "EndOfScript") {
                $queueResult = Add-FileToQueue -Queue $FilesToDelete -FilePath $SourceFilePath -ValidateFile $false
                $queuedForEndOfScriptDeletion = [bool]$queueResult
                if (-not $queuedForEndOfScriptDeletion) {
                    Write-LogWarning "Failed to queue file for deletion: $SourceFilePath"
                }
            }
        }
        catch {
            if ($DeleteMode -eq "EndOfScript") {
                $queuedForEndOfScriptDeletion = $false
            }
            Write-LogWarning ($PostCopyFailureMessageTemplate -f $SourceFilePath, $_.Exception.Message)
        }
    }
    else {
        if ($CopyFailureIsWarning) {
            Write-LogWarning ($CopyFailureMessageTemplate -f $OriginalFileName, $destinationFile)
        }
        else {
            Write-LogError ($CopyFailureMessageTemplate -f $OriginalFileName, $destinationFile)
        }
    }

    if (-not $IncrementOnSuccessOnly -or $copySucceeded) {
        $GlobalFileCounter.Value++
    }

    if ($ShowProgress -and $TotalFiles -gt 0 -and ($GlobalFileCounter.Value % $UpdateFrequency -eq 0)) {
        $percentComplete = [math]::Floor(($GlobalFileCounter.Value / $TotalFiles) * 100)
        $status = $ProgressStatusTemplate -f $GlobalFileCounter.Value, $TotalFiles
        Write-Progress -Activity $ProgressActivity -Status $status -PercentComplete $percentComplete
    }

    return [pscustomobject]@{
        Success         = $copySucceeded
        DestinationFile = $destinationFile
        QueueQueued     = $queuedForEndOfScriptDeletion
    }
}
