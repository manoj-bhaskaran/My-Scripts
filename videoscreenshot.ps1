<#
.SYNOPSIS
This PowerShell script processes video files from a specified source folder, takes screenshots at regular intervals, and then crops the screenshots using a Python script.

.DESCRIPTION
The script allows for configurable parameters, such as the maximum number of videos to process in a single run and the time limit for processing videos. Additionally, it supports command-line parameters to override these default values and handles interrupts gracefully.

.PARAMETER TimeLimit
Maximum time in minutes for processing videos in a single run. Overrides the default value of $timeLimitInMinutes.

.PARAMETER VideoLimit
Maximum number of videos to process in a single run. Overrides the default value of $videoLimit.

.EXAMPLES
To run the script with the default values:
.\videoscreenshot.ps1

To specify a time limit of 15 minutes and a video limit of 10:
.\videoscreenshot.ps1 -TimeLimit 15 -VideoLimit 10

.NOTES
Script Workflow:
1. Initialization:
   - Configurable delays, time limits, and video limits are set.
   - Source folder, save path, log file path, and Python script path are defined.
   - Command-line parameters are parsed to override default values, if provided.

2. Prerequisite Checks:
   - The script checks if the source folder exists.
   - It verifies if VLC Media Player is installed and available in the system path.
   - It checks if the Python cropping script exists.

3. Setup:
   - A save directory is created if it does not exist.
   - The log file is checked to determine if it is a fresh start. If so, existing screenshots are cleared.

4. Interrupt Handling:
   - A signal handler is added to detect interrupt signals (e.g., Ctrl+C) to stop processing new videos and proceed to the cropping step.

5. Video Processing:
   - All video files in the source folder are listed.
   - Processed videos are filtered out, and the remaining videos are processed.
   - Screenshots are taken at regular intervals until the time limit or video limit is reached, or an interrupt signal is received.

6. Error Handling and Cleanup:
   - Any errors during processing are logged.
   - VLC processes are terminated if still running after an error or interrupt.

7. Python Script Execution:
   - The Python script is called to crop the screenshots.

8. Completion:
   - The script logs the completion of processing and deletes the log file if all videos are processed.
#>

# Configurable parameters
$initialDelay = 200          # Time to wait for VLC to open (milliseconds)
$screenshotInterval = 500    # Interval between screenshots (milliseconds)
$timeLimitInMinutes = 10     # Maximum time limit for processing videos (default value in minutes)
$videoLimit = 5              # Maximum number of videos to process in a single run (default value)


# Define paths
$sourceFolderPath = "C:\Users\manoj\Downloads"
$savePath = "C:\Users\manoj\OneDrive\Desktop\Screenshots"
$logFilePath = "$savePath\processed_videos.log"  # Path to the log file
$pythonScriptPath = "C:\Users\manoj\Documents\Scripts\crop_colours.py"

# Helper function to log messages with timestamps
function Write-Message {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $message"
}

# Parse command-line arguments
param (
    [int]$TimeLimit = $timeLimitInMinutes,
    [int]$VideoLimit = $videoLimit
)

# Override default values with command-line arguments, if provided
$timeLimitInMinutes = $TimeLimit
$videoLimit = $VideoLimit

if (-not (Test-Path -Path $sourceFolderPath)) {
    Write-Message "Error: Source folder does not exist. Please check the path: $sourceFolderPath"
    exit
}

if (-not (Get-Command "vlc.exe" -ErrorAction SilentlyContinue)) {
    Write-Message "Error: VLC Media Player is not installed or not in the system path."
    exit
}

if (-not (Test-Path -Path $pythonScriptPath)) {
    Write-Message "Error: Python cropping script not found at $pythonScriptPath"
    exit
}

# Create save directory if it does not exist
New-Item -ItemType Directory -Force -Path $savePath | Out-Null

# Determine if this is a fresh start
$freshStart = -not (Test-Path -Path $logFilePath)

# Ensure the log file exists or create an empty one
if ($freshStart) {
    New-Item -Path $logFilePath -ItemType File | Out-Null
    Write-Message "Log file created at $logFilePath"
}

# Load processed video paths from the log file
$processedVideos = @()
if ((Get-Content -Path $logFilePath | Measure-Object).Count -gt 0) {
    $processedVideos = Get-Content -Path $logFilePath
    Write-Message "Loaded $(($processedVideos).Count) processed video(s) from log."
}

# Clear existing screenshots only for fresh starts
if ($freshStart) {
    Get-ChildItem -Path $savePath -Recurse -File | Remove-Item -Force
    Write-Message "Cleared existing screenshots from $savePath"
}

# Load required .NET assemblies for GDI+
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Add a signal handler to detect Ctrl+C
$script:interrupted = $false
[Console]::CancelKeyPress += {
    $script:interrupted = $true
    $_.Cancel = $true
    Write-Message "Interrupt signal received. Stopping new video processing..."
}

# Function to capture the screen using GDI+
function Get-ScreenWithGDIPlus {
    param ([string]$filePath)

    # Screen resolution is hardcoded
    $screenWidth = 1920
    $screenHeight = 1080

    # Create a bitmap with the current screen resolution
    $bitmap = New-Object System.Drawing.Bitmap $screenWidth, $screenHeight
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    # Capture the screen
    $graphics.CopyFromScreen(0, 0, 0, 0, [System.Drawing.Size]::new($screenWidth, $screenHeight))
    $bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)

    # Clean up resources
    $graphics.Dispose()
    $bitmap.Dispose()
}

$currentRunCount = 0
$startTime = Get-Date # Record the start time

# Get all video files in the source folder
$allVideoFiles = Get-ChildItem -Path $sourceFolderPath -Recurse -Include *.mp4, *.avi, *.mkv

# Filter out videos that are already processed
$videoFiles = $allVideoFiles | Where-Object { $_.FullName -notin $processedVideos }
if ($videoFiles.Count -eq 0) {
    Write-Message "No unprocessed videos found. Exiting."
    exit
}

# Limit the number of videos to process
$videoFiles = $videoFiles[0..([Math]::Min($videoLimit, $videoFiles.Count) - 1)]

try {
    foreach ($video in $videoFiles) {
        Write-Message "Processing video: $($video.Name)"
        Write-Message "Processing video $($currentRunCount + 1) of $($videoFiles.Count)"

        # Check for interrupt signal
        if ($script:interrupted) {
            Write-Message "Processing interrupted. Proceeding to cropping step."
            break
        }

        # Start VLC for the current video
        $vlcProcess = Start-Process -FilePath "vlc.exe" -ArgumentList "`"$($video.FullName)`"", "--fullscreen", "--no-video-title-show", "--qt-minimal-view", "--no-qt-privacy-ask", "--video-on-top", "--play-and-exit" -PassThru

        if (-not $vlcProcess) {
            Write-Message "Error: VLC process could not be started for video $($video.Name)."
            continue
        }

        Start-Sleep -Milliseconds $initialDelay  # Allow VLC to start

        # Capture screenshots until VLC exits
        while ($vlcProcess.HasExited -eq $false) {
            $file = "$savePath\Screenshot_$((Get-Date).ToString('yyyyMMddHHmmssfff')).png"
            Get-ScreenWithGDIPlus -filePath $file
            Write-Message "Screenshot saved: $file"
            Start-Sleep -Milliseconds $screenshotInterval

            # Check if the time limit has been reached
            $elapsedTime = (Get-Date) - $startTime
            if ($elapsedTime.TotalMinutes -ge $timeLimitInMinutes) {
                Write-Message "Time limit of $timeLimitInMinutes minutes reached. Proceeding to cropping step."
                break
            }

            # Check for interrupt signal
            if ($script:interrupted) {
                Write-Message "Processing interrupted. Proceeding to cropping step."
                break
            }
        }

        # Log the processed video
        Add-Content -Path $logFilePath -Value $video.FullName

        $currentRunCount++
        Write-Message "Finished processing video: $($video.Name)"

        # Stop if video limit is reached
        if ($currentRunCount -eq $videoLimit) {
            Write-Message "Video limit of $videoLimit reached. Proceeding to cropping step."
            break
        }

        # Check if the time limit has been reached
        $elapsedTime = (Get-Date) - $startTime
        if ($elapsedTime.TotalMinutes -ge $timeLimitInMinutes) {
            Write-Message "Time limit of $timeLimitInMinutes minutes reached. Proceeding to cropping step."
            break
        }
    }
} catch {
    Write-Message "An error occurred during processing: $($_.Exception.Message)"

    # Cleanup VLC process if running
    if ($vlcProcess -and -not $vlcProcess.HasExited) {
        $vlcProcess.Kill()
        Write-Message "VLC process terminated."
    }
}

# Check if all videos are processed and delete log file if true
if (($allVideoFiles | Measure-Object).Count -eq $processedVideos.Count + $currentRunCount) {
    Remove-Item -Path $logFilePath -Force
    Write-Message "All videos processed. Deleted log file."
}

# Call the Python script to crop images
try {
    Write-Message "Calling Python cropping script: $pythonScriptPath"
    $pythonOutput = python $pythonScriptPath $savePath 2>&1
    Write-Message "Python script output: $pythonOutput"

    if ($LastExitCode -ne 0) {
        Write-Message "Error: Python script execution failed with exit code $LastExitCode."
    } else {
        Write-Message "Python script executed successfully."
    }
} catch {
    Write-Message "Error during Python script execution: $($_.Exception.Message)"
}

Write-Message "Processing completed."
