<#
.SYNOPSIS
    Scans scheduled tasks and exports updated definitions with modified script paths as UTF-8 XML files.

.DESCRIPTION
    This script does NOT directly modify live scheduled tasks.

    It exports updated task definitions that reflect corrected script paths under a refactored folder structure.
    You can manually re-import the modified XML files using Register-ScheduledTask or schtasks /Create.

    This script scans non-system scheduled tasks and updates references to scripts located in:
        - C:\Users\manoj\Documents\Scripts
        - D:\My Scripts

    If the Command or Arguments reference a .ps1, .bat, or .py file in one of those folders,
    the path is rewritten to point to:
        - src\powershell
        - src\batch
        - src\python

    Modified task definitions are exported as UTF-8 encoded .xml files to:
        D:\My Scripts\Windows Task Scheduler

.NOTES
    Implements improvements:
    - Uses Export-ScheduledTask for exporting
    - Parses XML using XPath for full Exec node visibility
    - Handles regex path matching with subfolder tolerance
    - Ensures UTF-8 export using StreamWriter
    - Writes detailed status messages per task

#>

$targetRoot1 = "C:\Users\manoj\Documents\Scripts"
$targetRoot2 = "D:\My Scripts"
$outputDir   = "D:\My Scripts\Windows Task Scheduler"

$extensionMap = @{
    ".ps1" = "src\powershell"
    ".bat" = "src\batch"
    ".py"  = "src\python"
}

if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Get-ScheduledTask | Where-Object {
    $_.TaskPath -notlike "\Microsoft*" -and $_.TaskPath -notlike "\Windows*"
} | ForEach-Object {
    $taskName = $_.TaskName
    $taskPath = $_.TaskPath
    $fullTaskName = "$taskPath$taskName"
    Write-Host "🔍 Scanning task: $fullTaskName"

    try {
        $exported = Export-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop

        if ($null -eq $exported) {
            Write-Warning "⚠ Exported task is null: $fullTaskName"
            continue
        }

        $xmlDoc = [xml]$exported

        $commandNode = $xmlDoc.SelectSingleNode("//Exec/Command")
        $argumentsNode = $xmlDoc.SelectSingleNode("//Exec/Arguments")

        if (-not $commandNode) {
            Write-Warning "⚠ Command node missing in task: $fullTaskName"
        }
        if (-not $argumentsNode) {
            Write-Host "ℹ Arguments node missing in task: $fullTaskName"
        }

        $originalCommand = $commandNode.InnerText
        $originalArguments = $argumentsNode.InnerText
        Write-Host "🔧 Command:   $originalCommand"
        Write-Host "🔧 Arguments: $originalArguments"

        $modified = $false

        foreach ($ext in $extensionMap.Keys) {
            $extEscaped = [regex]::Escape($ext)

            foreach ($root in @($targetRoot1, $targetRoot2)) {
                $escapedRoot = [regex]::Escape($root)
                $pattern = '(?i)"?' + $escapedRoot + '\\.*' + $extEscaped + '"?'

                if ($originalCommand -match $pattern) {
                    $filename = Split-Path -Leaf $originalCommand
                    $newPath = Join-Path (Join-Path $root $extensionMap[$ext]) $filename
                    $commandNode.InnerText = $originalCommand -ireplace $pattern, $newPath
                    $modified = $true
                }

                if ($originalArguments -match $pattern) {
                    $filename = Split-Path -Leaf $originalArguments
                    $newPath = Join-Path (Join-Path $root $extensionMap[$ext]) $filename
                    $argumentsNode.InnerText = $originalArguments -ireplace $pattern, $newPath
                    $modified = $true
                }
            }
        }

        if ($modified) {
            $outPath = Join-Path $outputDir "$taskName.xml"
            try {
                $writer = [System.IO.StreamWriter]::new($outPath, $false, [System.Text.Encoding]::UTF8)
                $xmlDoc.Save($writer)
                $writer.Dispose()
                Write-Host "✅ Updated and exported: $taskName" -ForegroundColor Green
            }
            catch {
                Write-Warning "⚠ Failed to write task XML for ${fullTaskName}: $($_.Exception.Message)"
            }
        }
        else {
            Write-Host "ℹ No changes needed for: $taskName" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "⚠ Failed to process task: $fullTaskName ($($_.Exception.Message))"
    }
}
