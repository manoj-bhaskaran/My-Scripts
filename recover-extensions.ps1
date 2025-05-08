<#
.SYNOPSIS
Wrapper to run recover_extensions.py from C:\Users\manoj\Documents\Scripts

.DESCRIPTION
This PowerShell script ensures the Python environment is set up and runs recover_extensions.py
with matching parameters. The Python virtual environment is created (if not already present),
and required packages are installed from requirements.txt.

.PARAMETERS
Same as the Python script: FolderPath, LogFilePath, UnknownsFolder, DryRun, MoveUnknowns, Debug, LogWriteIntervalSeconds
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

# Fixed script paths
$BaseDir = "C:\Users\manoj\Documents\Scripts"
$PythonScript = Join-Path $BaseDir "recover_extensions.py"
$RequirementsFile = Join-Path $BaseDir "requirements.txt"
$VenvDir = Join-Path $BaseDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"

# Create virtual environment if needed
if (-not (Test-Path $VenvPython)) {
    Write-Host "Creating virtual environment..."
    python -m venv $VenvDir
}

# Install/update dependencies
Write-Host "Installing dependencies from requirements.txt..."
& $VenvPython -m pip install --upgrade pip
& $VenvPython -m pip install -r $RequirementsFile

# Build Python argument list
$ArgsList = @(
    "--folder", "`"$FolderPath`"",
    "--log", "`"$LogFilePath`"",
    "--unknowns", "`"$UnknownsFolder`"",
    "--log-interval", "$LogWriteIntervalSeconds"
)
if ($DryRun) { $ArgsList += "--dryrun" }
if ($MoveUnknowns) { $ArgsList += "--move-unknowns" }
if ($Debug) { $ArgsList += "--debug" }

# Execute the script
Write-Host "Running Python script..."
& $VenvPython $PythonScript @ArgsList
