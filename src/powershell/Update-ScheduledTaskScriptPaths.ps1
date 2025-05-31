<#
.SYNOPSIS
    Updates script paths in Windows Task Scheduler tasks and exports the modified definitions as UTF-8 encoded XML files.

.DESCRIPTION
    This script scans all non-system scheduled tasks on the local machine and checks the command and arguments fields
    for any references to scripts in the old flat structure under:
        - C:\Users\manoj\Documents\Scripts
        - D:\My Scripts

    If a script path matches and ends in .ps1, .bat, or .py, it rewrites the path to point to the new structured
    subfolder layout:
        - PowerShell scripts → src\powershell\
        - Batch scripts     → src\batch\
        - Python scripts    → src\python\

    The updated task definitions are saved as UTF-8 encoded XML files to the specified output folder, overwriting
    existing files if present. System-level tasks (e.g., under \Microsoft or \Windows) are skipped.

.PARAMETER None
    This script takes no parameters. You may edit the $targetRoot1, $targetRoot2, and $outputDir variables inside
    the script to suit your environment.

.OUTPUTS
    UTF-8 encoded .xml files in the specified export directory.

.NOTES
    Author: Your Name
    Created: 2025-05-31
    Tested on: Windows 10+, PowerShell 5.1+

    Be sure to run with appropriate permissions to read all intended tasks.

.EXAMPLE
    ./Update-ScheduledTaskScriptPaths.ps1

    This will process all eligible tasks, rewrite script paths if required, and export updated .xml files to:
    D:\My Scripts\Windows Task Scheduler
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
    $escapedTaskName = '"' + $fullTaskName + '"'

    try {
        # Export task to temp XML
        $tempXmlPath = [System.IO.Path]::GetTempFileName()
        schtasks /Query /TN $escapedTaskName /XML > $tempXmlPath 2>$null

        $xml = [xml](Get-Content $tempXmlPath -Raw)

        $execNode = $xml.Task.Actions.Exec
        $command  = $execNode.Command
        $arguments = $execNode.Arguments
        $allText = "$command $arguments"

        $modified = $false

        foreach ($ext in $extensionMap.Keys) {
            $extEscaped = [regex]::Escape($ext)
            $regex1 = [regex]::Escape($targetRoot1) + "\\([^""\\]+$extEscaped)"
            if ($allText -match $regex1) {
                $file = $matches[1]
                $newPath = Join-Path $targetRoot1 ($extensionMap[$ext] + "\" + $file)
                $allText = $allText -replace [regex]::Escape($targetRoot1 + "\" + $file), $newPath
                $modified = $true
            }

            $regex2 = [regex]::Escape($targetRoot2) + "\\([^""\\]+$extEscaped)"
            if ($allText -match $regex2) {
                $file = $matches[1]
                $newPath = Join-Path $targetRoot2 ($extensionMap[$ext] + "\" + $file)
                $allText = $allText -replace [regex]::Escape($targetRoot2 + "\" + $file), $newPath
                $modified = $true
            }
        }

        if ($modified) {
            $updatedText = $allText.Trim()
            $firstToken = $updatedText -split '\s+' | Select-Object -First 1
            $rest = $updatedText.Substring($firstToken.Length).Trim()

            $xml.Task.Actions.Exec.Command   = $firstToken
            $xml.Task.Actions.Exec.Arguments = $rest

            $outPath = Join-Path $outputDir "$taskName.xml"
            $xml.Save($outPath)

            # Convert encoding to UTF-8
            $utf8 = [System.Text.Encoding]::UTF8
            [System.IO.File]::WriteAllText($outPath, (Get-Content $outPath -Raw), $utf8)

            Write-Host "✅ Updated and exported: $taskName" -ForegroundColor Green
        } else {
            Remove-Item $tempXmlPath -Force
        }

    } catch {
        Write-Warning "⚠ Failed to process task: $fullTaskName ($($_.Exception.Message))"
    }
}
