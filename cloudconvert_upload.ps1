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

    # Run the Python script
    $result = & $pythonExecutable $scriptPath --debug upload_file $FilePath

    # Check if output is captured
    if ($result -eq "") {
        Write-Host "No output captured from Python script." -ForegroundColor Red
    } else {
        Write-Host "Result from CloudConvert:" $result
    }
}
