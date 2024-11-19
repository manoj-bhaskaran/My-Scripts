# Define the Python executable and script path
$pythonExecutable = "python"  # Use "python3" if needed
$scriptPath = "C:\Users\manoj\Documents\Scripts\cloudconvert_utils.py"  # Replace with the actual path to your Python script

# Function to authenticate and upload a file
function Send-FileToCloudConvert {
    param (
        [string]$FileName
    )

    if (-not (Test-Path $FileName)) {
        Write-Host "File '$FileName' does not exist."
        return
    }

    # Check if the -Debug flag is set
    $debugFlag = if ($Debug) { "--debug" } else { "" }

    Write-Host "Debug Flag: $debugFlag"
    # Call the Python script for file upload
    $result = & $pythonExecutable $scriptPath $debugFlag upload_file $FilePath

    # Display the result
    Write-Host "Result from CloudConvert:" $result
}

