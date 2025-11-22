<#
.SYNOPSIS
    This script checks which processes are holding a specified file using Handle.exe.

.DESCRIPTION
    The script uses the Sysinternals Handle utility to determine which processes are holding a specified file.
    The path to the file to be checked must be provided as a mandatory command-line parameter.

.PARAMETER FileToCheck
    The path to the file you want to check for open handles.

.EXAMPLE
    .\handle.ps1 -FileToCheck "D:\Path\To\Your\File.jar"

.NOTES
    VERSION: 2.0.0
    CHANGELOG:
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.0.0 - Initial release
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$FileToCheck
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName "handle" -LogLevel 20

# If no parameter is provided, check for command-line arguments
if (-not $FileToCheck -and $args.Count -gt 0) {
    $FileToCheck = $args[0]
}

Write-LogInfo "Checking file handles for: $FileToCheck"

# Define the path to the Handle.exe utility
$handlePath = "C:\Users\manoj\Documents\Scripts\Handle\handle.exe"  # Update this path to where you have handle.exe

# Check if handle.exe exists at the specified path
if (-not (Test-Path $handlePath)) {
    Write-LogError "Handle.exe not found at $handlePath. Please check the path and try again."
    exit
}

Write-LogDebug "Using Handle.exe at: $handlePath"

# Run Handle.exe with the file path
try {
    # Invoke the handle.exe process
    $handleOutput = & "$handlePath" $FileToCheck 2>&1

    # Check if handle.exe returned any output
    if ($handleOutput -match "No matching handles found") {
        Write-LogInfo "No processes are holding the file $FileToCheck."
    }
    else {
        Write-LogInfo "Processes holding the file ${FileToCheck}:"
        Write-LogInfo $handleOutput
    }
}
catch {
    Write-LogError "An error occurred while running Handle.exe: $_"
}
