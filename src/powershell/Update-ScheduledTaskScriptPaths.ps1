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
    - Ensures UTF-8 export without re-reading files
    - Always cleans up resources

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

    try {
        $xml = Export-ScheduledTask -TaskName $taskName -TaskPath $taskPath
        $execNode = $xml.Task.Actions.Exec
        $originalCommand = $execNode.Command
        $originalArguments = $execNode.Arguments
        $modified = $false

        foreach ($ext in $extensionMap.Keys) {
            $extEscaped = [regex]::Escape($ext)

            foreach ($root in @($targetRoot1, $targetRoot2)) {
                $escapedRoot = [regex]::Escape($root)
                $pattern = "$escapedRoot\\.*$extEscaped"

                if ($originalCommand -match $pattern) {
                    $filename = Split-Path -Leaf $originalCommand
                    $newPath = Join-Path (Join-Path $root $extensionMap[$ext]) $filename
                    $execNode.Command = $originalCommand -replace $pattern, $newPath
                    $modified = $true
                }

                if ($originalArguments -match $pattern) {
                    $filename = Split-Path -Leaf $originalArguments
                    $newPath = Join-Path (Join-Path $root $extensionMap[$ext]) $filename
                    $execNode.Arguments = $originalArguments -replace $pattern, $newPath
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
            } finally {
                if ($writer) { $writer.Close() }
            }
            Write-Host "✅ Updated and exported: $taskName" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "⚠ Failed to process task: $fullTaskName ($($_.Exception.Message))"
    }
}
