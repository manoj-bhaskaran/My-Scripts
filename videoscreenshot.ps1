# Configurable delays (in milliseconds)
$initialDelay = 200          # Time to wait for VLC to open
$screenshotInterval = 500    # Interval between screenshots

# Define paths
$sourceFolderPath = "C:\Users\manoj\Downloads"
$savePath = "C:\Users\manoj\OneDrive\Desktop\Screenshots"
$logFilePath = "$savePath\processed_videos.log"  # Path to the log file
$pythonScriptPath = "C:\Users\manoj\Documents\Scripts\crop_colours.py"

# Configurable parameters
$videoLimit = 5  # Maximum number of videos to process in a single run

# Helper function to log messages with timestamps
function Write-Message {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $message"
}

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
    }
} catch {
    Write-Message "An error occurred during processing: $($_.Exception.Message)"
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
