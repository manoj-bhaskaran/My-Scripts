<#
.SYNOPSIS
    Re-registers scheduled tasks from exported XML definition files.

.DESCRIPTION
    This script automates the re-importation of scheduled task definitions
    that were previously exported as XML files. It's intended to be used
    after modifying script paths within the XML definitions using the
    companion Update-ScheduledTaskPathRefactor.ps1 script.

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
    - FIX: Uses System.Xml.XmlDocument.Load() for the most robust and auto-detecting XML parsing.
#>
function Sync-ScheduledTasksFromXml {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$XmlSourceDirectory = "D:\My Scripts\Windows Task Scheduler"
    )

    # Ensure the script is run as Administrator
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "This script needs to be run with Administrator privileges. Please re-run PowerShell as Administrator."
        return
    }

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
        Write-Host "`nProcessing XML file: $($xmlFile.FullName)" -ForegroundColor Cyan

        try {
            # *** FIX: Use System.Xml.XmlDocument.Load() for robust XML parsing ***
            # This method automatically handles BOMs and encoding declarations within the XML.
            $xmlDoc = New-Object System.Xml.XmlDocument
            $xmlDoc.Load($xmlFile.FullName) # Load directly from file path

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

            Write-Host "  Detected Task Name: '${taskName}'" -ForegroundColor DarkCyan # Added {} for clarity
            Write-Host "  Detected Task Path: '${taskPath}'" -ForegroundColor DarkCyan # Added {} for clarity

            # Use ShouldProcess for safety, especially since we're overwriting tasks
            if ($PSCmdlet.ShouldProcess("${taskPath}${taskName}", "Register task from $($xmlFile.BaseName)")) {
                $registerParams = @{
                    TaskName    = $taskName
                    TaskPath    = $taskPath
                    Xml         = $xmlDoc.OuterXml # Use OuterXml to get the full XML string including declaration
                    Force       = $true
                    ErrorAction = 'Stop'
                }

                # Conditional logic to add -User and -Password for specific tasks
                # IMPORTANT: This section needs to be uncommented and adapted based on your task settings.
                # Find the actual user account for these tasks in Task Scheduler (General tab).
                # Example: if your task runs as 'LENOVOLAPTOP\manoj' with "Run whether user is logged on or not" checked
                if ($taskName -eq "PostgreSQL Gnucash Backup" -or $taskName -eq "Sync Macrium Backups") {
                    $taskUser = "LENOVOLAPTOP\manoj" # Adjust this to the correct user name for your system
                    Write-Host "  Prompting for password for user '$taskUser' for task '${taskName}'." -ForegroundColor Yellow
                    $taskPassword = Read-Host -AsSecureString "Enter password for '$taskUser':"

                    $registerParams.Add("User", $taskUser)
                    $registerParams.Add("Password", $taskPassword)

                    Write-Host "  Registering task '${taskName}' with explicit user credentials." -ForegroundColor DarkYellow
                } else {
                    Write-Host "  Registering task '${taskName}' using XML-defined user context (e.g., SYSTEM, or run only when user is logged on)." -ForegroundColor DarkYellow
                }

                # Execute Register-ScheduledTask with the collected parameters
                Register-ScheduledTask @registerParams

                Write-Host "✅ Successfully registered/updated task: ${taskPath}${taskName}" -ForegroundColor Green
            } else {
                Write-Host "Skipped re-registration of task: ${taskPath}${taskName} (WhatIf/Confirm triggered)" -ForegroundColor Gray
            }
        }
        catch {
            Write-Warning "⚠ Failed to register task from $($xmlFile.FullName): $($_.Exception.Message)"
        }
    }

    Write-Host "`nRe-registration process completed." -ForegroundColor Green
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