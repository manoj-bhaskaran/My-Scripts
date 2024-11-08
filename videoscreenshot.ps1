# Path to the video file you want to play
$videoPath = "C:\Users\manoj\OneDrive\Desktop\New folder (2)\eaa40b8b667e430d910f6ff4122e21fa.mp4"

# Path where screenshots will be saved
$savePath = "C:\Users\manoj\OneDrive\Desktop\Screenshots"
New-Item -ItemType Directory -Force -Path $savePath

# Clear out any existing PNG files from the Screenshots folder
Get-ChildItem -Path $savePath -Filter *.png -File | Remove-Item -Force

# Duration of the video in seconds (set this based on your video length)
$videoDuration = 13  # Adjust this to the actual video length in seconds

# Configurable delays
$initialDelay = 200  # Milliseconds to wait until VLC opens
$screenshotInterval = 250  # Milliseconds between screenshots

# Start VLC Media Player with the video in fullscreen and without the control bar
$vlcProcess = Start-Process -FilePath "vlc.exe" -ArgumentList "`"$videoPath`"", "--fullscreen", "--no-video-title-show", "--qt-minimal-view", "--no-qt-privacy-ask", "--video-on-top" -PassThru
Start-Sleep -Milliseconds $initialDelay  # Wait for VLC to open

# Load required .NET assemblies for GDI+
Add-Type -AssemblyName System.Drawing

# Hardcoded resolution values (1920x1080)
$screenWidth = 1920
$screenHeight = 1080

# Function to capture the screen using GDI+
function Capture-ScreenWithGDIPlus {
    param (
        [string]$filePath  # File path where the screenshot will be saved
    )

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

# Start capturing screenshots, tracking time to stop after video duration
$startTime = Get-Date
$elapsedTime = 0

while ($elapsedTime -lt $videoDuration) {
    $file = "$savePath\Screenshot_$($elapsedTime).png"
    Capture-ScreenWithGDIPlus -filePath $file
    Write-Output "Screenshot saved to $file"
    
    # Wait for the configured interval between screenshots
    Start-Sleep -Milliseconds $screenshotInterval
    $elapsedTime = (New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds
}

# Close VLC after capturing screenshots
Stop-Process -Name "vlc" -Force

# Call python script to crop images
# Set the path to the Python script
$scriptPath = "C:\Users\manoj\Documents\scripts\crop_colours.py"

# Run the Python script
python $scriptPath $savePath

Write-Output "Image cropping completed."