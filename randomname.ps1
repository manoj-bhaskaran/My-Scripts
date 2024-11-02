# Function to generate a random file name
function Get-RandomFileName {
    # Exclude problematic characters: \ / : * ? " < > | and others that might cause issues.
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789~!@$()_-+=QWERTYUIOPASDFGHJKLZXCVBNM'
    $namelen = Get-Random -Maximum 32 -Minimum 4
    $randomName = -join ((0..$namelen) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

    if ($randomName[0] -eq '(' -or $randomName[0] -eq ')') {
        # Filter out '(' from the available characters
        $filteredChars = $chars -replace '[()]'
        # Select a random character that is not '('
        $newFirstChar = $filteredChars[(Get-Random -Maximum $filteredChars.Length)]
        # Replace the first character with the new one
        $randomName = $newFirstChar + $randomName.Substring(1)
    }
    return $randomName
}

# Define the folder path
$folderPath = "C:\Users\manoj\OneDrive\Desktop\New folder"

# Check if the folder exists
if (-Not (Test-Path -Path $folderPath -PathType Container)) {
    Write-Host "The folder path '$folderPath' does not exist."
    exit 1
}

# Get all files in the folder
$files = Get-ChildItem -Path $folderPath -File

# Counter for renamed files
$renamedCount = 0

# Loop through each file to rename
foreach ($file in $files) {
    try {
        # Get the file extension
        $extension = $file.Extension

        # Generate a new file name
        $newFileName = Get-RandomFileName

        # Construct the new file path with the new file name and original extension
        $newFilePath = Join-Path -Path $folderPath -ChildPath ($newFileName + $extension)

        # Check if the new file name already exists to avoid overwriting
        if (Test-Path -Path $newFilePath) {
            throw "The file '$newFilePath' already exists."
        }

        # Rename the file
        Rename-Item -LiteralPath $file.FullName -NewName ($newFileName + $extension) -Force

        # Increment the count of renamed files
        $renamedCount++

        # Write progress every 1000 files
        if ($renamedCount % 1000 -eq 0) {
            $percentComplete = [math]::Round(($renamedCount / $files.Count) * 100, 2)
            Write-Host "$renamedCount files renamed. $percentComplete% files renamed."
        }
    } catch {
        # Output the file name that caused the error and the error message
        Write-Host "Error renaming file '$($file.FullName)': $_"
    }
}

# Output the total count of files renamed
Write-Host "Total files renamed: $renamedCount"
