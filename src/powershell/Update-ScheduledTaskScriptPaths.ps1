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
    - Ensures UTF-8 export using StreamWriter and proper Dispose (without BOM)
    - **CRITICAL FIX:** Explicitly updates the XML declaration's 'encoding' attribute to 'utf-8'.
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

# Ensure the output directory exists
if (-not (Test-Path -Path $outputDir)) {
    Write-Host "Creating output directory: $outputDir" -ForegroundColor DarkCyan
    New-Item -ItemType Directory -Path $outputDir | Out-Null
} else {
    Write-Host "Output directory already exists: $outputDir" -ForegroundColor DarkCyan
}

Write-Host "Starting scan and export of scheduled tasks..." -ForegroundColor Green

Get-ScheduledTask | Where-Object {
    # Exclude Microsoft and Windows system tasks
    $_.TaskPath -notlike "\Microsoft*" -and $_.TaskPath -notlike "\Windows*"
} | ForEach-Object {
    $taskName = $_.TaskName
    $taskPath = $_.TaskPath
    $fullTaskName = "$taskPath$taskName"
    Write-Host "`n🔍 Scanning task: $fullTaskName" -ForegroundColor Cyan

    try {
        # Export the task definition as XML. Export-ScheduledTask typically outputs UTF-16 XML.
        [xml]$xmlDoc = Export-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop

        # --- CRITICAL FIX: Update the XML declaration's encoding attribute ---
        # Get the first child node, which should be the XML declaration (e.g., <?xml ...?>)
        $xmlDeclaration = $xmlDoc.FirstChild
        if ($xmlDeclaration -is [System.Xml.XmlDeclaration]) {
            # If the encoding attribute exists and is not already "utf-8"
            if ($xmlDeclaration.Encoding -and $xmlDeclaration.Encoding -ne "utf-8") {
                $xmlDeclaration.Encoding = "utf-8"
                $modified = $true # Mark as modified because we changed the declaration
                Write-Host "✅ Updated XML declaration encoding attribute to 'utf-8' for $fullTaskName" -ForegroundColor Green
            } else {
                 Write-Host "ℹ XML declaration encoding already 'utf-8' or not specified for $fullTaskName" -ForegroundColor DarkGray
            }
        } else {
            Write-Warning "⚠ XML declaration not found as first child for task: $fullTaskName. Cannot update encoding attribute." -ForegroundColor Yellow
            # If a task XML does not have an XML declaration, it's technically malformed,
            # but Export-ScheduledTask usually ensures one is present.
        }
        # --- END CRITICAL FIX ---


        # Initialize XmlNamespaceManager for XPath queries (essential for task XML)
        $nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
        $nsMgr.AddNamespace("t", "http://schemas.microsoft.com/windows/2004/02/mit/task")

        # Select the Command and Arguments nodes using XPath
        $commandNode = $xmlDoc.SelectSingleNode("//t:Exec/t:Command", $nsMgr)
        $argumentsNode = $xmlDoc.SelectSingleNode("//t:Exec/t:Arguments", $nsMgr)

        # Get original values, handling cases where nodes might be missing
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

        Write-Host "🔧 Original Command:   $originalCommand" -ForegroundColor DarkYellow
        Write-Host "🔧 Original Arguments: $originalArguments" -ForegroundColor DarkYellow

        # Flag to track if any modifications were made to the task definition
        # (This will also be true if only the XML declaration was updated)
        # We initialized $modified based on XML declaration update.
        # If no declaration, or already utf-8, it remains false until paths are modified.

        # Iterate through defined extensions and target roots to find and replace paths
        foreach ($ext in $extensionMap.Keys) {
            foreach ($root in @($targetRoot1, $targetRoot2)) {
                # Regex pattern to match paths with optional quotes and subfolders
                # E.g., "C:\Users\manoj\Documents\Scripts\Subfolder\script.ps1"
                # or D:\My Scripts\another_script.bat
                $escapedRoot = [regex]::Escape($root)
                $escapedExt = [regex]::Escape($ext)
                # Matches either "root\anything.ext" or root\anything.ext
                $pattern = "(?i)(""?)$escapedRoot\\.*?$escapedExt(""?)" # Capture optional quotes

                # Check and modify Command node
                if ($originalCommand -match $pattern) {
                    $matchedPath = $Matches[0] # The entire matched path including quotes
                    $filename = Split-Path -Leaf $matchedPath.Trim('"') # Get filename, remove quotes first
                    $newRelativePath = Join-Path $extensionMap[$ext] $filename
                    $newFullPath = Join-Path $root $newRelativePath

                    # Reconstruct with original quotes if they existed
                    $newCommand = $originalCommand -ireplace $pattern, "$($Matches[1])$newFullPath$($Matches[2])"

                    if ($commandNode.InnerText -ne $newCommand) {
                        $commandNode.InnerText = $newCommand
                        $modified = $true
                        Write-Host "🔄 Updated Command path for ${taskName}: '$newCommand'" -ForegroundColor Magenta
                    }
                }

                # Check and modify Arguments node (only if arguments exist)
                if ($originalArguments -and $originalArguments -match $pattern) {
                    $matchedPath = $Matches[0]
                    $filename = Split-Path -Leaf $matchedPath.Trim('"')
                    $newRelativePath = Join-Path $extensionMap[$ext] $filename
                    $newFullPath = Join-Path $root $newRelativePath

                    $newArguments = $originalArguments -ireplace $pattern, "$($Matches[1])$newFullPath$($Matches[2])"

                    if ($argumentsNode.InnerText -ne $newArguments) {
                        $argumentsNode.InnerText = $newArguments
                        $modified = $true
                        Write-Host "🔄 Updated Arguments path for ${taskName}: '$newArguments'" -ForegroundColor Magenta
                    }
                }
            }
        }

        # If any modifications were made (including XML declaration update or path changes), export the XML
        if ($modified) {
            $outPath = Join-Path $outputDir "$taskName.xml"
            try {
                # Explicitly create a UTF8Encoding object that does NOT emit a BOM
                $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)

                # Use this custom encoding object with StreamWriter
                # $false for 'append' means overwrite existing file
                $writer = [System.IO.StreamWriter]::new($outPath, $false, $utf8NoBomEncoding)
                $xmlDoc.Save($writer)
                $writer.Dispose() # Crucial to release the file handle
                Write-Host "✅ Updated and exported: $taskName to '$outPath' (UTF-8 No BOM)" -ForegroundColor Green
            }
            catch {
                Write-Warning "⚠ Failed to write task XML for ${fullTaskName}: $($_.Exception.Message)"
            }
        } else {
            Write-Host "ℹ No functional changes needed for: $taskName (XML declaration might have been updated, but paths were not changed)" -ForegroundColor Gray
        }
    }
    catch {
        # Catch any errors during Export-ScheduledTask or XML processing for a specific task
        Write-Warning "⚠ Failed to process task: $fullTaskName ($($_.Exception.Message))"
    }
}

Write-Host "`nScan and export process completed." -ForegroundColor Green