<#
.SYNOPSIS
Wrapper to run recover_extensions.py from C:\Users\manoj\Documents\Scripts\src\python

.DESCRIPTION
This PowerShell script ensures the Python environment is set up and runs recover_extensions.py
with matching parameters. The Python virtual environment is created (if not already present),
and required packages are installed from requirements.txt.

.PARAMETERS
Same as the Python script: FolderPath, LogFilePath, UnknownsFolder, DryRun, MoveUnknowns, Debug, LogWriteIntervalSeconds

.NOTES
Version: 2.0.0

CHANGELOG
## 2.0.0 - 2025-11-16
### Changed
- Migrated to PowerShellLoggingFramework.psm1 for standardized logging
- Replaced Write-Host calls with Write-LogInfo
#>

param(
    [string]$FolderPath = "C:\Users\manoj\OneDrive\Desktop\New folder",
    [string]$LogFilePath = "C:\Users\manoj\Documents\Scripts\recover-extensions-log.txt",
    [string]$UnknownsFolder = "C:\Users\manoj\OneDrive\Desktop\UnidentifiedFiles",
    [switch]$DryRun,
    [switch]$MoveUnknowns,
    [switch]$Debug,
    [int]$LogWriteIntervalSeconds = 5
)

# Import logging framework
Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

# Initialize logger
Initialize-Logger -ScriptName (Split-Path -Leaf $PSCommandPath) -LogLevel 20

# Fixed script paths
$BaseDir = "C:\Users\manoj\Documents\Scripts\src\python"
$PythonScript = Join-Path $BaseDir "recover_extensions.py"
$RequirementsFile = Join-Path $BaseDir "requirements.txt"
$VenvDir = Join-Path $BaseDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"

# Create virtual environment if needed
if (-not (Test-Path $VenvPython)) {
    Write-LogInfo "Creating virtual environment..."
    python -m venv $VenvDir
}

# Install/update dependencies
Write-LogInfo "Installing dependencies from requirements.txt..."
& $VenvPython -m pip install --upgrade pip *> $null
& $VenvPython -m pip install -r $RequirementsFile *> $null

# Build Python argument list
$ArgsList = @(
    "--folder", $FolderPath,
    "--log", $LogFilePath,
    "--unknowns", $UnknownsFolder,
    "--log-interval", "$LogWriteIntervalSeconds"
)
if ($DryRun) { $ArgsList += "--dryrun" }
if ($MoveUnknowns) { $ArgsList += "--move-unknowns" }
if ($Debug) { $ArgsList += "--debug" }

# Execute the script
Write-LogInfo "Running Python script..."
& $VenvPython $PythonScript @ArgsList
