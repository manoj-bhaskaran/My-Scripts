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

    # Construct argument list
    $arguments = @()
    if ($Debug) {
        $arguments += "--debug"
    }
    $arguments += $FileName  # No manual quotes needed
    $arguments += $OutputFormat

    # Debug print: Show command before execution
    Write-Host "Executing: $pythonExecutable $scriptPath $arguments"

    # Execute the Python script
    $result = & $pythonExecutable $scriptPath @arguments

    # Display the result
    Write-Host "Result from CloudConvert:" $result
}
