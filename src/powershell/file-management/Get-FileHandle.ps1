<#
.SYNOPSIS
    This script checks which processes are holding a specified file using Handle.exe.

.DESCRIPTION
    The script uses the Sysinternals Handle utility to determine which processes are holding a specified file.
    The path to the file to be checked must be provided as a mandatory command-line parameter.

.PARAMETER FileToCheck
    The path to the file you want to check for open handles.

.PARAMETER HandleExePath
    The path to the Handle.exe utility. If not specified, uses environment variable HANDLE_EXE_PATH
    or defaults to tools/Handle/handle.exe in the repository.

.EXAMPLE
    .\handle.ps1 -FileToCheck "D:\Path\To\Your\File.jar"

.EXAMPLE
    .\handle.ps1 -FileToCheck "D:\Path\To\Your\File.jar" -HandleExePath "C:\Tools\handle.exe"

.NOTES
    VERSION: 3.0.0
    CHANGELOG:
        3.0.0 - Removed hardcoded paths, added portable path resolution (Issue #513)
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.0.0 - Initial release
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$FileToCheck,

    [string]$HandleExePath
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

# Determine the path to the Handle.exe utility
if (-not $HandleExePath) {
    # Try environment variable first
    if ($env:HANDLE_EXE_PATH) {
        $handlePath = $env:HANDLE_EXE_PATH
        Write-LogDebug "Using Handle.exe from environment variable: $handlePath"
    }
    # Fall back to repository tools directory
    else {
        $scriptRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $handlePath = Join-Path $scriptRoot "tools" "Handle" "handle.exe"
        Write-LogDebug "Using default Handle.exe location: $handlePath"
    }
}
else {
    $handlePath = $HandleExePath
}

# Check if handle.exe exists at the specified path
if (-not (Test-Path $handlePath)) {
    $errorMsg = @"
Handle.exe not found at: $handlePath

To fix this issue:
1. Download Handle.exe from: https://docs.microsoft.com/en-us/sysinternals/downloads/handle
2. Place it in: $scriptRoot\tools\Handle\handle.exe
3. Or set the HANDLE_EXE_PATH environment variable to point to handle.exe
4. Or use the -HandleExePath parameter to specify the path

Example:
    [Environment]::SetEnvironmentVariable("HANDLE_EXE_PATH", "C:\Tools\handle.exe", "User")
"@
    Write-LogError $errorMsg
    throw "Handle.exe not found at: $handlePath"
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
