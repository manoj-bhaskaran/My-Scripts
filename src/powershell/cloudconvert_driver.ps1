<#
.SYNOPSIS
    Wrapper to run CloudConvert file conversion via Python.
.DESCRIPTION
    Executes a Python script to convert files using the CloudConvert API.
.NOTES
    VERSION: 2.0.0
    CHANGELOG:
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.0.0 - Initial release
#>

# Import logging framework
Import-Module "$PSScriptRoot\..\common\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName "cloudconvert_driver" -LogLevel 20

function Convert-FileWithCloudConvert {
    param (
        [string]$FileName,
        [string]$OutputFormat,
        [switch]$Debug
    )

    Write-LogInfo "Converting file: $FileName to format: $OutputFormat"

    if (-not (Test-Path $FileName)) {
        Write-LogError "File '$FileName' does not exist."
        return
    }

    $pythonExecutable = "python"  # Change to "python3" if required
    $scriptPath = "C:\Users\manoj\Documents\Scripts\src\python\cloudconvert_utils.py"

    Write-LogDebug "Python executable: $pythonExecutable"
    Write-LogDebug "Script path: $scriptPath"

    # Construct argument list
    $arguments = @()
    if ($Debug) {
        $arguments += "--debug"
        Write-LogDebug "Debug mode enabled"
    }
    $arguments += $FileName  # No manual quotes needed
    $arguments += $OutputFormat

    # Execute the Python script
    try {
        $result = & $pythonExecutable $scriptPath @arguments
        Write-LogInfo "CloudConvert conversion completed successfully"
        Write-LogInfo "Result from CloudConvert: $result"
    }
    catch {
        Write-LogError "CloudConvert conversion failed: $($_.Exception.Message)"
        throw
    }
}
