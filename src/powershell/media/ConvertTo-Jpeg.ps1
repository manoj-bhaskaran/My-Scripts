<#
.SYNOPSIS
    Convert image files to JPEG using WinRT APIs.
.DESCRIPTION
    Converts various image formats to JPEG format using Windows Runtime APIs.
    Optionally fixes extension of JPEG files without the .jpg extension.
.PARAMETER Files
    Array of image file names to convert to JPEG
.PARAMETER FixExtensionIfJpeg
    Fix extension of JPEG files without the .jpg extension
.NOTES
    VERSION: 2.0.0
    CHANGELOG:
        2.0.0 - Refactored to use PowerShellLoggingFramework for standardized logging
        1.0.0 - Initial release
#>

param (
    [Parameter(
        Mandatory = $true,
        Position = 1,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        ValueFromRemainingArguments = $true,
        HelpMessage = "Array of image file names to convert to JPEG")]
    [Alias("FullName")]
    [String[]]
    $Files,

    [Parameter(
        HelpMessage = "Fix extension of JPEG files without the .jpg extension")]
    [Switch]
    $FixExtensionIfJpeg
)

begin {
    # Import logging framework
    Import-Module "$PSScriptRoot\..\modules\Core\Logging\PowerShellLoggingFramework.psm1" -Force

    # Initialize logger
    Initialize-Logger -ScriptName "ConvertTo-Jpeg" -LogLevel 20

    Write-LogInfo "Starting JPEG conversion process"

    # Technique for await-ing WinRT APIs: https://fleexlab.blogspot.com/2018/02/using-winrts-iasyncoperation-in.html
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $runtimeMethods = [System.WindowsRuntimeSystemExtensions].GetMethods()
    $asTaskGeneric = ($runtimeMethods | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    function AwaitOperation ($WinRtTask, $ResultType) {
        $asTaskSpecific = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTaskSpecific.Invoke($null, @($WinRtTask))
        $netTask.Wait() | Out-Null
        $netTask.Result
    }
    $asTask = ($runtimeMethods | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
    function AwaitAction ($WinRtTask) {
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait() | Out-Null
    }

    # Reference WinRT assemblies
    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime] | Out-Null
}

process {
    # Summary of imaging APIs: https://docs.microsoft.com/en-us/windows/uwp/audio-video-camera/imaging
    $processedCount = 0
    $skippedCount = 0
    $errorCount = 0

    foreach ($file in $Files) {
        Write-LogDebug "Processing file: $file"
        try {
            try {
                # Get SoftwareBitmap from input file
                $file = Resolve-Path -LiteralPath $file
                $inputFile = AwaitOperation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($file)) ([Windows.Storage.StorageFile])
                $inputFolder = AwaitOperation ($inputFile.GetParentAsync()) ([Windows.Storage.StorageFolder])
                $inputStream = AwaitOperation ($inputFile.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
                $decoder = AwaitOperation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($inputStream)) ([Windows.Graphics.Imaging.BitmapDecoder])
            }
            catch {
                # Ignore non-image files
                Write-LogWarning "Unsupported file format: $file"
                $skippedCount++
                continue
            }
            if ($decoder.DecoderInformation.CodecId -eq [Windows.Graphics.Imaging.BitmapDecoder]::JpegDecoderId) {
                $extension = $inputFile.FileType
                if ($FixExtensionIfJpeg -and ($extension -ne ".jpg") -and ($extension -ne ".jpeg")) {
                    # Rename JPEG-encoded files to have ".jpg" extension
                    $newName = $inputFile.Name -replace ($extension + "$"), ".jpg"
                    AwaitAction ($inputFile.RenameAsync($newName))
                    Write-LogInfo "Renamed JPEG file: $file => $newName"
                    $processedCount++
                }
                else {
                    # Skip JPEG-encoded files
                    Write-LogDebug "Already JPEG: $file"
                    $skippedCount++
                }
                continue
            }
            $bitmap = AwaitOperation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])

            # Write SoftwareBitmap to output file
            $outputFileName = $inputFile.Name -replace ($extension + "$"), ".jpg";
            $outputFile = AwaitOperation ($inputFolder.CreateFileAsync($outputFileName, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
            $outputStream = AwaitOperation ($outputFile.OpenAsync([Windows.Storage.FileAccessMode]::ReadWrite)) ([Windows.Storage.Streams.IRandomAccessStream])
            $encoder = AwaitOperation ([Windows.Graphics.Imaging.BitmapEncoder]::CreateAsync([Windows.Graphics.Imaging.BitmapEncoder]::JpegEncoderId, $outputStream)) ([Windows.Graphics.Imaging.BitmapEncoder])
            $encoder.SetSoftwareBitmap($bitmap)
            $encoder.IsThumbnailGenerated = $true

            # Do it
            AwaitAction ($encoder.FlushAsync())
            Write-LogInfo "Converted to JPEG: $file -> $outputFileName"
            $processedCount++
        }
        catch {
            # Report full details
            Write-LogError "Failed to convert $file: $($_.Exception.ToString())"
            $errorCount++
        }
        finally {
            # Clean-up
            if ($inputStream -ne $null) { [System.IDisposable]$inputStream.Dispose() }
            if ($outputStream -ne $null) { [System.IDisposable]$outputStream.Dispose() }
        }
    }

    Write-LogInfo "JPEG conversion completed. Processed: $processedCount, Skipped: $skippedCount, Errors: $errorCount"
}
