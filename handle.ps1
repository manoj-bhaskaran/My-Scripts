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
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$FileToCheck
)

# Define the path to the Handle.exe utility
$handlePath = "C:\Users\manoj\Documents\Scripts\Handle\handle.exe"  # Update this path to where you have handle.exe

# Check if handle.exe exists at the specified path
if (-not (Test-Path $handlePath)) {
    Write-Host "Handle.exe not found at $handlePath. Please check the path and try again."
    exit
}

# Run Handle.exe with the file path
try {
    # Invoke the handle.exe process
    $handleOutput = & "$handlePath " $FileToCheck 2>&1

    # Check if handle.exe returned any output
    if ($handleOutput -match "No matching handles found") {
        Write-Host "No processes are holding the file $FileToCheck."
    } else {
        Write-Host "Processes holding the file ${FileToCheck}:"
        Write-Host $handleOutput
    }
} catch {
    Write-Host "An error occurred: $_"
}
