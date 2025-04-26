# Define the source and destination directories
$sourceDir = "C:\Users\manoj\OneDrive\Desktop\New folder"
$destDir = "C:\Users\manoj\OneDrive\Desktop"

# Define the configurable file limit for each directory
$fileLimit = 200 # You can change this value as needed

# Get the current timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Initialize counters
$renamedJpegCount = 0
$copiedFilesCount = @{}
$notCopiedJpgCount = 0

# Hashtable to keep track of the number of files and the counter for each extension
$extensionFileCount = @{}
$extensionCounter = @{}

# Get all files from the source directory and rename .jpeg to .jpg
$files = Get-ChildItem -Path $sourceDir -File | ForEach-Object {
    if ($_.Extension -ieq ".jpeg") {
        Rename-Item -Path $_.FullName -NewName ([System.IO.Path]::ChangeExtension($_.FullName, ".jpg"))
        $_ = Get-Item ([System.IO.Path]::ChangeExtension($_.FullName, ".jpg"))
        $renamedJpegCount++
    }
    $_
}

# Process each file
foreach ($file in $files) {
    $extension = $file.Extension.TrimStart('.').ToLower()
    
    if ($extension -eq "jpg") {
        # Use Regex to perform a case-sensitive match for lowercase 'img'
        if (-not [regex]::Match($file.Name, '^img', [System.Text.RegularExpressions.RegexOptions]::None).Success) {
            $notCopiedJpgCount++
            continue
        }
    } elseif ($extension -eq "png") {
        # Skip copying PNG files by default
        continue
    }

    # Initialize counters if not already done
    if (-not $extensionFileCount.ContainsKey($extension)) {
        $extensionFileCount[$extension] = 0
        $extensionCounter[$extension] = 1
    }
    
    # Increment the file count for the extension
    $extensionFileCount[$extension]++
    
    # Check if a new directory needs to be created
    if ($extensionFileCount[$extension] > $fileLimit) {
        $extensionCounter[$extension]++
        $extensionFileCount[$extension] = 1 # Reset the count for the new directory
    }
    
    # Create the directory name following the specified naming convention
    $dirName = "picconvert_" + $timestamp + "_" + $extension+ "_" + $extensionCounter[$extension]
    $newDir = Join-Path -Path $destDir -ChildPath $dirName
    
    # Create the directory if it doesn't exist
    if (-not (Test-Path -Path $newDir)) {
        New-Item -Path $newDir -ItemType Directory | Out-Null
    }
    
    # Copy the file to the new directory
    $copiedFile = Copy-Item -Path $file.FullName -Destination $newDir -PassThru
    
    # Verify the copy and delete the original file if successful
    if ($copiedFile) {
        Remove-Item -Path $file.FullName
        if (-not $copiedFilesCount.ContainsKey($extension)) {
            $copiedFilesCount[$extension] = 0
        }
        $copiedFilesCount[$extension]++
    }
}

# Output the results
Write-Output "Renamed .jpeg files: $renamedJpegCount"
foreach ($extension in $copiedFilesCount.Keys) {
    Write-Output "Copied .$extension files: $($copiedFilesCount[$extension])"
}

if ($notCopiedJpgCount -gt 0) {
    Write-Output "Not copied .jpg files (not starting with 'img'): $notCopiedJpgCount"
}