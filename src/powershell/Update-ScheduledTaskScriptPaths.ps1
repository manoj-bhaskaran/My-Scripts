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
    - Uses Export-ScheduledTask instead of schtasks.exe
    - Safely updates Command and Arguments fields separately
    - Handles regex path matching with subfolder tolerance
    - Ensures UTF-8 export using proper StreamWriter disposal
    - Always cleans up resources with try/catch/finally
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

    Write-Host "🔍 Scanning task: $fullTaskName" -ForegroundColor Cyan

    try {
        $xml = Export-ScheduledTask -TaskName $taskName -TaskPath $taskPath
        $execNode = $xml.Task.Actions.Exec
        Write-Host "🔧 Command:   $($execNode.Command)"
        Write-Host "🔧 Arguments: $($execNode.Arguments)"
        $modified = $false

        foreach ($ext in $extensionMap.Keys) {
            $extEscaped = [regex]::Escape($ext)

            foreach ($root in @($targetRoot1, $targetRoot2)) {
                $escapedRoot = [regex]::Escape($root)
                $pattern = "(?i)" + $escapedRoot + "\\.*" + $extEscaped

                if ($execNode.Command -match $pattern) {
                    $filename = Split-Path -Leaf $execNode.Command
                    $newPath = Join-Path (Join-Path $root $extensionMap[$ext]) $filename
                    $execNode.Command = $execNode.Command -replace $pattern, $newPath
                    $modified = $true
                }

                if ($execNode.Arguments -match $pattern) {
                    $filename = Split-Path -Leaf $execNode.Arguments
                    $newPath = Join-Path (Join-Path $root $extensionMap[$ext]) $filename
                    $execNode.Arguments = $execNode.Arguments -replace $pattern, $newPath
                    $modified = $true
                }
            }
        }

        if ($modified) {
            $outPath = Join-Path $outputDir "$taskName.xml"
            $writer = $null
            try {
                $writer = New-Object System.IO.StreamWriter($outPath, $false, [System.Text.Encoding]::UTF8)
                $xml.Save($writer)
            }
            catch {
                Write-Warning "⚠ Failed to write task XML for ${fullTaskName}: $($_.Exception.Message)"
                return
            }
            finally {
                if ($writer) { $writer.Dispose() }
            }
            Write-Host "✅ Updated and exported: $taskName" -ForegroundColor Green
        }
        else {
            Write-Host "ℹ No changes needed for: $taskName" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Warning "⚠ Failed to process task: $fullTaskName ($($_.Exception.Message))"
    }
}
