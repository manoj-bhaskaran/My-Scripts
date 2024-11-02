# Define the path to the Handle.exe utility
$handlePath = "C:\Users\manoj\Documents\Scripts\Handle\handle.exe"  # Update this path to where you have handle.exe

# Define the file you want to check
$fileToCheck = "D:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2024.1.4\plugins\java-coverage\lib\java-coverage.jar"  # Update this path to the file you want to check

# Check if handle.exe exists at the specified path
if (-not (Test-Path $handlePath)) {
    Write-Host "Handle.exe not found at $handlePath. Please check the path and try again."
    exit
}

# Run Handle.exe with the file path
try {
    # Invoke the handle.exe process
    $handleOutput = & "$handlePath " $fileToCheck 2>&1

    # Check if handle.exe returned any output
    if ($handleOutput -match "No matching handles found") {
        Write-Host "No processes are holding the file $fileToCheck."
    } else {
        Write-Host "Processes holding the file ${fileToCheck}:"
        Write-Host $handleOutput
    }
} catch {
    Write-Host "An error occurred: $_"
}
