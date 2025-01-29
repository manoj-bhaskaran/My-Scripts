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

    # Construct the argument list properly
    $arguments = @()
    if ($Debug) {
        $arguments += "--debug"
    }
    $arguments += "`"$FileName`""  # Wrap in quotes to handle spaces
    $arguments += $OutputFormat

    # Debug print: Show command before execution
    Write-Host "Executing: $pythonExecutable $scriptPath $arguments"

    # Execute the Python script
    $result = & $pythonExecutable $scriptPath @arguments

    # Display the result
    Write-Host "Result from CloudConvert:" $result
}
