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
    - Uses Export-ScheduledTask for exporting (Reverted to this for robustness)
    - Parses XML using XPath with NamespaceManager for full Exec node visibility
    - Handles regex path matching with subfolder tolerance and optional quotes
    - Ensures UTF-8 export using StreamWriter and proper Dispose
    - Writes detailed status messages per task
    - Validates presence of nodes before accessing them
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
        # *** REVERTED TO EXPORT-SCHEDULEDTASK ***
        # This is generally more reliable and idiomatic PowerShell
        [xml]$xmlDoc = Export-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop

        $nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
        $nsMgr.AddNamespace("t", "http://schemas.microsoft.com/windows/2004/02/mit/task")

        $commandNode = $xmlDoc.SelectSingleNode("//t:Exec/t:Command", $nsMgr)
        $argumentsNode = $xmlDoc.SelectSingleNode("//t:Exec/t:Arguments", $nsMgr)

        # *** CORRECTED: Explicitly check for null before accessing InnerText ***
        $originalCommand = if ($commandNode) { $commandNode.InnerText } else { "" }
        $originalArguments = if ($argumentsNode) { $argumentsNode.InnerText } else { "" }

        # Node presence checks and colored output
        if (-not $commandNode) {
            Write-Host "⚠ Command node missing in task: $fullTaskName (Skipping modifications for this task)" -ForegroundColor Yellow
            # If no command node, no point in processing further for this task
            return
        }
        if (-not $argumentsNode) {
            Write-Host "ℹ Arguments node missing in task: $fullTaskName" -ForegroundColor DarkGray
        }

        Write-Host "🔧 Command:   $originalCommand" -ForegroundColor DarkYellow
        Write-Host "🔧 Arguments: $originalArguments" -ForegroundColor DarkYellow

        $modified = $false

        foreach ($ext in $extensionMap.Keys) {
            foreach ($root in @($targetRoot1, $targetRoot2)) {
                $pattern = '(?i)\"?' + [regex]::Escape($root) + '\\.*' + [regex]::Escape($ext) + '\"?'

                if ($originalCommand -match $pattern) {
                    $filename = Split-Path -Leaf $originalCommand
                    $newPath = Join-Path (Join-Path $root $extensionMap[$ext]) $filename
                    $commandNode.InnerText = $originalCommand -ireplace $pattern, $newPath
                    $modified = $true # <--- FIX: Changed 'true' to $true
                }

                if ($originalArguments -and $originalArguments -match $pattern) {
                    $filename = Split-Path -Leaf $originalArguments
                    $newPath = Join-Path (Join-Path $root $extensionMap[$ext]) $filename
                    $argumentsNode.InnerText = $originalArguments -ireplace $pattern, $newPath
                    $modified = $true # <--- FIX: Changed 'true' to $true
                }
            }
        }

        if ($modified) {
            $outPath = Join-Path $outputDir "$taskName.xml"
            try {
                # *** FIX: Explicitly create a UTF8Encoding object that does NOT emit a BOM ***
                $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false) # The $false parameter means 'do not emit BOM'

                # Use this custom encoding object with StreamWriter
                $writer = [System.IO.StreamWriter]::new($outPath, $false, $utf8NoBomEncoding)
                $xmlDoc.Save($writer)
                $writer.Dispose()
                Write-Host "✅ Updated and exported: $taskName (UTF-8 No BOM)" -ForegroundColor Green
            }
            catch {
                Write-Warning "⚠ Failed to write task XML for ${fullTaskName}: $($_.Exception.Message)"
            }
        } else {
            Write-Host "ℹ No changes needed for: $taskName" -ForegroundColor Gray
        }
    }
    catch {
        # Catch any errors during Export-ScheduledTask or XML processing
        Write-Warning "⚠ Failed to process task: $fullTaskName ($($_.Exception.Message))"
    }
}