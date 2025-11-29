<#
.SYNOPSIS
    Wrapper to run CloudConvert file conversion via Python.
.DESCRIPTION
    Executes a Python script to convert files using the CloudConvert API.
.NOTES
    VERSION: 3.0.0
    CHANGELOG:
        3.0.0 - Removed hardcoded paths, added portable path resolution (Issue #513)
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.0.0 - Initial release
#>

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName "cloudconvert_driver" -LogLevel 20

function Convert-FileWithCloudConvert {
    param (
        [string]$FileName,
        [string]$OutputFormat,
        [string]$PythonScript,
        [switch]$Debug
    )

    Write-LogInfo "Converting file: $FileName to format: $OutputFormat"

    if (-not (Test-Path $FileName)) {
        Write-LogError "File '$FileName' does not exist."
        return
    }

    # Determine Python script path
    if (-not $PythonScript) {
        # Use relative path from this script's location
        # From src/powershell/cloud/ to src/python/
        $scriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $PythonScript = Join-Path $scriptRoot "src" "python" "cloudconvert_utils.py"
    }

    # Validate Python script exists
    if (-not (Test-Path $PythonScript)) {
        $errorMsg = "Python script not found: $PythonScript`n" +
                    "Please ensure the cloudconvert_utils.py script exists in the repository."
        Write-LogError $errorMsg
        throw $errorMsg
    }

    $pythonExecutable = "python"  # Change to "python3" if required

    Write-LogDebug "Python executable: $pythonExecutable"
    Write-LogDebug "Script path: $PythonScript"

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
        $result = & $pythonExecutable $PythonScript @arguments
        Write-LogInfo "CloudConvert conversion completed successfully"
        Write-LogInfo "Result from CloudConvert: $result"
    }
    catch {
        Write-LogError "CloudConvert conversion failed: $($_.Exception.Message)"
        throw
    }
}
