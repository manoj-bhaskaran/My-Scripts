# Configurable delays (in milliseconds)
$initialDelay = 200          # Time to wait for VLC to open
$screenshotInterval = 500    # Interval between screenshots
$vlcPollingInterval = 500    # Interval for checking VLC process status

# Define the source folder and screenshot path
$sourceFolderPath = "C:\Users\manoj\Downloads"
$savePath = "C:\Users\manoj\OneDrive\Desktop\Screenshots"
New-Item -ItemType Directory -Force -Path $savePath

# Load required .NET assemblies for GDI+
Add-Type -AssemblyName System.Drawing

# Function to capture the screen using GDI+
function Capture-ScreenWithGDIPlus {
    param (
        [string]$filePath  # File path where the screenshot will be saved
    )

    # Hardcoded resolution values (1920x1080)
    $screenWidth = 1920
    $screenHeight = 1080

    # Create a bitmap with hardcoded resolution
    $bitmap = New-Object System.Drawing.Bitmap $screenWidth, $screenHeight
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    # Capture the screen with hardcoded resolution
    $graphics.CopyFromScreen(0, 0, 0, 0, [System.Drawing.Size]::new($screenWidth, $screenHeight))
    $bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)

    # Clean up resources
    $graphics.Dispose()
    $bitmap.Dispose()
}

# Clear existing screenshots once before starting video processing
Get-ChildItem -Path $savePath -Filter *.png -File | Remove-Item -Force
Write-Output "Cleared existing screenshots from $savePath"

# Get all video files in the source folder with multiple extensions
$videoFiles = Get-ChildItem -Path $sourceFolderPath -Recurse -Include *.mp4, *.avi, *.mkv

foreach ($video in $videoFiles) {
    Write-Output "Processing video: $($video.Name)"
    
    # Start VLC for the current video
    $vlcProcess = Start-Process -FilePath "vlc.exe" -ArgumentList "`"$($video.FullName)`"", "--fullscreen", "--no-video-title-show", "--qt-minimal-view", "--no-qt-privacy-ask", "--video-on-top", "--play-and-exit" -PassThru
    Start-Sleep -Milliseconds $initialDelay  # Allow VLC to start
    
    # Capture screenshots until VLC exits
    while ($vlcProcess.HasExited -eq $false) {
        $file = "$savePath\Screenshot_$((Get-Date).ToString('yyyyMMddHHmmss')).png"
        Capture-ScreenWithGDIPlus -filePath $file
        Write-Output "Screenshot saved: $file"
        Start-Sleep -Milliseconds $screenshotInterval  # Interval between screenshots
    }
    
    # Wait for VLC to fully exit before proceeding to the next video
    while (-not $vlcProcess.HasExited) {
        Start-Sleep -Milliseconds $vlcPollingInterval  # Poll VLC process state
    }

    Write-Output "Finished processing video: $($video.Name)"
}

Write-Output "All videos processed successfully!"

# Call the Python script to crop images
$pythonScriptPath = "C:\Users\manoj\Documents\Scripts\crop_colours.py"
Write-Output "Calling Python cropping script: $pythonScriptPath"
python $pythonScriptPath $savePath

Write-Output "Cropping completed!"
Write-Output "All videos processed successfully!"
