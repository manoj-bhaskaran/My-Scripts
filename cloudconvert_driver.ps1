# Function to authenticate, upload, and convert a file
function Convert-FileWithCloudConvert {
    param (
        [string]$FileName,
        [string]$OutputFormat,
        [switch]$Debug  # Explicitly define a Debug flag
    )

    if (-not (Test-Path $FileName)) {
        Write-Host "File '$FileName' does not exist."
        return
    }

    # Determine the debug flag
    $debugFlag = if ($Debug) { "--debug" } else { "" }

    # Construct the command properly
    $arguments = @()
    if ($Debug) {
        $arguments += "--debug"
    }
    $arguments += $FileName
    $arguments += $OutputFormat

    # Call the Python script for file conversion
    $result = & $pythonExecutable $scriptPath @arguments

    # Display the result
    Write-Host "Result from CloudConvert:" $result
}
