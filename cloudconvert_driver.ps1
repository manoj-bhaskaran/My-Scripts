function Convert-FileWithCloudConvert {
    param (
        [string]$FileName,
        [string]$OutputFormat,
        [switch]$Debug
    )

    if (-not (Test-Path $FileName)) {
        Write-Host "File '$FileName' does not exist."
        return
    }

    $pythonExecutable = "python"  # Change to "python3" if required
    $scriptPath = "C:\Users\manoj\Documents\Scripts\cloudconvert_utils.py"

    # Construct argument list
    $arguments = @()
    if ($Debug) {
        $arguments += "--debug"
    }
    $arguments += $FileName  # No manual quotes needed
    $arguments += $OutputFormat

    # Execute the Python script
    $result = & $pythonExecutable $scriptPath @arguments

    # Display the result
    Write-Host "Result from CloudConvert:" $result
}
