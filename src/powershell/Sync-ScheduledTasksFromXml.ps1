<#
.SYNOPSIS
    Re-registers scheduled tasks from exported XML definition files.

.DESCRIPTION
    This script automates the re-importation of scheduled task definitions
    that were previously exported as XML files. It's intended to be used
    after modifying script paths within the XML definitions.

    It iterates through all XML files in a specified directory, extracts
    the task name and path from each XML, and then re-registers the task
    using Register-ScheduledTask.

    Existing tasks with the same name will be overwritten.

.PARAMETER XmlSourceDirectory
    Specifies the directory where the exported XML task definitions are located.
    Defaults to "D:\My Scripts\Windows Task Scheduler".

.NOTES
    - Requires administrative privileges to run.
    - If tasks run under specific user accounts with stored passwords
      ("Run whether user is logged on or not"), you will need to
      manually provide those credentials during re-registration,
      as passwords are NOT stored in the XML. This script includes a
      section where you can add this logic if needed.
    - Uses Register-ScheduledTask for robust and native PowerShell integration.
    - Provides detailed status messages during the process.
#>
function Sync-ScheduledTasksFromXml {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$XmlSourceDirectory = "D:\My Scripts\Windows Task Scheduler"
    )

    if (-not (Test-Path -Path $XmlSourceDirectory)) {
        Write-Error "The specified XML source directory '$XmlSourceDirectory' does not exist."
        return
    }

    $xmlFiles = Get-ChildItem -Path $XmlSourceDirectory -Filter "*.xml"

    if (-not $xmlFiles) {
        Write-Warning "No XML files found in '$XmlSourceDirectory'. Nothing to re-register."
        return
    }

    Write-Host "Starting re-registration of scheduled tasks from XML files in '$XmlSourceDirectory'..." -ForegroundColor Green
    Write-Host "NOTE: Existing tasks with matching names will be overwritten." -ForegroundColor Yellow

    foreach ($xmlFile in $xmlFiles) {
        Write-Host "Processing XML file: $($xmlFile.FullName)" -ForegroundColor Cyan

        try {
            # Read the XML content into an XML document object
            [xml]$xmlDoc = Get-Content -Path $xmlFile.FullName -Encoding UTF8 | Out-String

            # Initialize XmlNamespaceManager for XPath queries (essential for task XML)
            $nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
            $nsMgr.AddNamespace("t", "http://schemas.microsoft.com/windows/2004/02/mit/task")

            # Extract the full task URI (e.g., '\MyFolder\MyTask')
            $taskUriNode = $xmlDoc.SelectSingleNode("//t:RegistrationInfo/t:URI", $nsMgr)
            if (-not $taskUriNode) {
                Write-Warning "⚠ Could not find task URI in XML file: $($xmlFile.FullName). Skipping."
                continue
            }
            $fullTaskUri = $taskUriNode.InnerText

            # Determine the Task Name (e.g., 'MyTask') and Task Path (e.g., '\MyFolder\')
            # The TaskName is the last segment of the URI
            $taskName = ($fullTaskUri -split '\\')[-1]

            # The TaskPath is the URI without the task name, ensuring a leading and trailing backslash
            $taskPath = $fullTaskUri.Replace($taskName, '')
            if ($taskPath -eq '') {
                $taskPath = '\' # Default to root path if no specific folder is found
            }

            Write-Host "  Detected Task Name: '$taskName'" -ForegroundColor DarkCyan
            Write-Host "  Detected Task Path: '$taskPath'" -ForegroundColor DarkCyan

            # Use ShouldProcess for safety, especially since we're overwriting tasks
            if ($PSCmdlet.ShouldProcess("$taskPath$taskName", "Register task from $($xmlFile.BaseName)")) {
                # Re-register the task. -Force will overwrite if it exists.
                Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Xml $xmlDoc.OuterXml -Force -ErrorAction Stop

                # --- IMPORTANT: Handle tasks requiring specific user accounts and passwords ---
                # If any of your tasks are configured to "Run whether user is logged on or not"
                # with a specific user account (not System, LocalService, NetworkService),
                # you MUST provide the -User and -Password parameters here.
                # The XML does NOT store the password for security reasons.
                # You'll need to implement logic to map task names to their respective credentials.
                #
                # Example:
                # if ($taskName -eq "PostgreSQL Gnucash Backup") {
                #    $taskUser = "LENOVOLAPTOP\manoj" # Use full domain\username or .\username for local
                #    # It's best practice to prompt for password or get it from a secure source, not hardcode
                #    $taskPassword = Read-Host -AsSecureString "Enter password for $taskUser for task '$taskName':"
                #    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Xml $xmlDoc.OuterXml -User $taskUser -Password $taskPassword -Force -ErrorAction Stop
                #    Write-Host "  Registered task '$taskName' with specific user credentials." -ForegroundColor DarkGreen
                # } else {
                #    # For tasks running as System, LocalService, NetworkService, or "Run only when user is logged on",
                #    # the XML typically handles the user context.
                #    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Xml $xmlDoc.OuterXml -Force -ErrorAction Stop
                # }

                Write-Host "✅ Successfully registered/updated task: $taskPath$taskName" -ForegroundColor Green
            } else {
                Write-Host "Skipped re-registration of task: $taskPath$taskName (WhatIf/Confirm triggered)" -ForegroundColor Gray
            }
        }
        catch {
            Write-Warning "⚠ Failed to register task from $($xmlFile.FullName): $($_.Exception.Message)"
        }
    }

    Write-Host "Re-registration process completed." -ForegroundColor Green
}

# How to run the function:
# Simply call it without parameters to use the default XML source directory:
Sync-ScheduledTasksFromXml

# Or specify a different directory:
# Sync-ScheduledTasksFromXml -XmlSourceDirectory "C:\MyBackupTaskXmls"

# Use -WhatIf to preview changes without making them:
# Sync-ScheduledTasksFromXml -WhatIf

# Use -Confirm to be prompted before each task re-registration:
# Sync-ScheduledTasksFromXml -Confirm