# Enforce explicit variable declarations
Set-StrictMode -Version Latest

# Define source directory path
[string]$sourcePath = "C:\Users\manoj\Documents\FIFA 07\elib"

# Define path for log file
[string]$logFilePath = "C:\Users\manoj\Documents\Scripts\scrubname.log"

# Define strings to scrub from filenames and their replacements
$scrubStrings = @{
    "manojbhaskaran76_" = $null
    "_Instagram" = $null
    "_WhatsApp" = $null
    "Screenshot_" = $null
}

# End of input parameters

# Get current timestamp
[string]$timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

#Program variable declarations
[string]$string = ""
[System.IO.FileInfo[]]$files = $null
[System.IO.FileInfo]$file = $null
[string]$oldName = ""
[string]$newName = ""
[int]$suffix = ""
[string]$baseName = ""
[string]$extension = ""

# Check if log file exists, if not, create it
if (-not (Test-Path $logFilePath)) {
    New-Item -Path $logFilePath -ItemType File | Out-Null
}



# Iterate over each scrub string
foreach ($string in $scrubStrings.Keys) {

    # Display the string being processed
    Write-Host "Processing: $string"
    
    # Get files containing the current scrub string
    $files = Get-ChildItem -Path $sourcePath -Filter "*$string*"

    If ($files -ne $null) {

        # Display the number of files to be processed
        Write-Host "$($files.Count) files to be processed"

    } else {

        Write-Host "0 files to be processed"

    }

    # Iterate over each file
    foreach ($file in $files) {

        # Store current filename
        $oldName = $file.Name
        
        # Replace the scrub string with empty string in filename
        $newName = $oldName -replace $string

        # Check if filename has changed
        if ($oldName -ne $newName) {
		
            # Initialize suffix for avoiding filename conflicts
            $suffix = 1
            
            # Append suffix to filename if it already exists
	        while (Test-Path (Join-Path -Path $sourcePath -ChildPath $newName)) {
	            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($newName)
	            $extension = [System.IO.Path]::GetExtension($newName)
                $newName = "${baseName}_${suffix}${extension}"
                $suffix++
            }
		
	        # Rename the file
	        Rename-Item -Path $file.FullName -NewName $newName
	        
            # Log the renaming action
            Add-Content -Path $logFilePath -Value "$timeStamp - Renaming file: $oldName to $newName"
        }
    }
}