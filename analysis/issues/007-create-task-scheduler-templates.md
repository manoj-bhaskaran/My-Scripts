# ISSUE-007: Create Task Scheduler Templates with Placeholders

**Priority:** 🟠 HIGH
**Category:** Portability / Configuration / Automation
**Estimated Effort:** 6 hours
**Skills Required:** PowerShell, XML, Task Scheduler, Automation

---

## Problem Statement

All 8 XML files in `config/tasks/` contain hardcoded paths (e.g., `C:\Users\manoj\Documents\Scripts\`), making them unusable on other systems. Manual XML editing is error-prone and prevents automated deployment.

### Current State

**Affected Files:**
- `Monthly System Health Check.xml` (Line 64)
- `Postgres Log Cleanup.xml` (Line 49)
- `Delete Old Downloads.xml` (Line 66)
- `Drive Space Monitor.xml` (Lines 70-71)
- `Clear Old Recycle Bin Items.xml` (Line 51)
- `PostgreSQL Gnucash Backup.xml` (Line 73)
- `PostgreSQL timeline_data Backup.xml` (Line 55)

**Example Hardcoded Path:**
```xml
<Arguments>-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "C:\Users\manoj\Documents\Scripts\src\powershell\Invoke-SystemHealthCheck.ps1"</Arguments>
```

### Impact

- 🚫 **Not Portable:** Task definitions don't work on other systems
- 📝 **Manual Setup:** Users must edit XML files manually
- 🐛 **Error-Prone:** Easy to make XML syntax errors
- 🤖 **No Automation:** Can't script task installation
- 🔧 **Maintenance Burden:** Path changes require editing all XMLs

---

## Acceptance Criteria

- [ ] Create `.template` versions of all 8 XML files
- [ ] Replace hardcoded paths with `{{SCRIPT_ROOT}}` placeholder
- [ ] Create `Install-ScheduledTasks.ps1` script to generate actual XMLs
- [ ] Script validates paths before generating XMLs
- [ ] Script can install tasks to Task Scheduler
- [ ] Add uninstall script `Uninstall-ScheduledTasks.ps1`
- [ ] Update INSTALLATION.md with task setup instructions
- [ ] Test on fresh Windows system
- [ ] Original XMLs added to .gitignore (generated files)

---

## Implementation Plan

### Step 1: Create Template Files (1.5 hours)

```bash
# Convert each XML to template
cd config/tasks/

for file in *.xml; do
    # Create template version
    sed 's|C:\\Users\\manoj\\Documents\\Scripts|{{SCRIPT_ROOT}}|g' "$file" > "${file}.template"
done

# Add original XMLs to .gitignore
echo "" >> ../../.gitignore
echo "# Generated Task Scheduler XMLs" >> ../../.gitignore
echo "config/tasks/*.xml" >> ../../.gitignore
echo "!config/tasks/*.xml.template" >> ../../.gitignore
```

**Example Template:**
```xml
<!-- Monthly System Health Check.xml.template -->
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Actions>
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "{{SCRIPT_ROOT}}\src\powershell\Invoke-SystemHealthCheck.ps1"</Arguments>
      <WorkingDirectory>{{SCRIPT_ROOT}}</WorkingDirectory>
    </Exec>
  </Actions>
  <!-- ... rest of XML ... -->
</Task>
```

### Step 2: Create Installation Script (2.5 hours)

```powershell
# scripts/Install-ScheduledTasks.ps1

<#
.SYNOPSIS
    Installs scheduled tasks for My-Scripts automation

.DESCRIPTION
    Generates Task Scheduler XML files from templates and registers them.
    Replaces {{SCRIPT_ROOT}} placeholder with actual script directory.

.PARAMETER ScriptRoot
    Root directory where scripts are installed

.PARAMETER TaskPrefix
    Prefix for task names (default: "MyScripts-")

.PARAMETER WhatIf
    Show what would be installed without actually installing

.EXAMPLE
    .\Install-ScheduledTasks.ps1 -ScriptRoot "C:\Users\John\Documents\Scripts"
    Installs all scheduled tasks

.EXAMPLE
    .\Install-ScheduledTasks.ps1 -ScriptRoot $PWD -WhatIf
    Preview task installation
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({Test-Path $_})]
    [string]$ScriptRoot,

    [string]$TaskPrefix = "MyScripts-",

    [switch]$Force
)

# Import logging
Import-Module "$PSScriptRoot/../src/powershell/modules/Core/Logging/PowerShellLoggingFramework.psm1"
$logger = Initialize-Logger -ScriptName "Install-ScheduledTasks"

Write-LogInfo $logger "Starting scheduled task installation"
Write-LogInfo $logger "Script root: $ScriptRoot"

# Validate script root
$ScriptRoot = (Resolve-Path $ScriptRoot).Path

# Find all template files
$templatePath = Join-Path $ScriptRoot "config" "tasks"
$templates = Get-ChildItem -Path $templatePath -Filter "*.xml.template"

if ($templates.Count -eq 0) {
    Write-LogError $logger "No template files found in $templatePath"
    throw "No template files found"
}

Write-Host "Found $($templates.Count) task templates" -ForegroundColor Cyan
Write-Host ""

$installed = 0
$failed = 0

foreach ($template in $templates) {
    $taskName = $TaskPrefix + ($template.BaseName -replace '\.xml$', '')
    $outputFile = Join-Path $templatePath ($template.BaseName)

    Write-Host "Processing: $taskName" -ForegroundColor Yellow

    try {
        # Read template
        $content = Get-Content $template.FullName -Raw

        # Replace placeholder (escape backslashes for XML)
        $escapedPath = $ScriptRoot -replace '\\', '\\'
        $content = $content -replace '\{\{SCRIPT_ROOT\}\}', $ScriptRoot

        # Validate XML
        try {
            [xml]$xmlContent = $content
            Write-Verbose "XML validation passed"
        }
        catch {
            Write-LogError $logger "Invalid XML in $($template.Name): $_"
            throw "XML validation failed"
        }

        # Save generated XML
        if ($PSCmdlet.ShouldProcess($outputFile, "Generate XML")) {
            Set-Content -Path $outputFile -Value $content -Encoding UTF8
            Write-Verbose "Generated: $outputFile"
        }

        # Register task
        if ($PSCmdlet.ShouldProcess($taskName, "Register scheduled task")) {
            # Check if task already exists
            $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

            if ($existingTask -and -not $Force) {
                Write-LogWarning $logger "Task '$taskName' already exists. Use -Force to overwrite"
                Write-Host "  ⚠ Already exists (skipped)" -ForegroundColor Yellow
                continue
            }

            # Register/update task
            Register-ScheduledTask -TaskName $taskName -Xml (Get-Content $outputFile -Raw) -Force:$Force | Out-Null

            Write-LogInfo $logger "Installed task: $taskName"
            Write-Host "  ✓ Installed successfully" -ForegroundColor Green
            $installed++
        }
    }
    catch {
        Write-LogError $logger "Failed to install $taskName: $_"
        Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        $failed++
    }

    Write-Host ""
}

# Summary
Write-Host "=" * 60
Write-Host "Installation Summary:" -ForegroundColor Cyan
Write-Host "  Installed: $installed tasks" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed: $failed tasks" -ForegroundColor Red
}

Write-LogInfo $logger "Installation complete. Installed: $installed, Failed: $failed"

if ($installed -gt 0) {
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Review tasks in Task Scheduler"
    Write-Host "  2. Adjust schedules if needed"
    Write-Host "  3. Test tasks: Get-ScheduledTask -TaskName '$TaskPrefix*'"
}
```

### Step 3: Create Uninstall Script (1 hour)

```powershell
# scripts/Uninstall-ScheduledTasks.ps1

<#
.SYNOPSIS
    Uninstalls My-Scripts scheduled tasks

.PARAMETER TaskPrefix
    Prefix for task names (default: "MyScripts-")

.PARAMETER WhatIf
    Show what would be uninstalled without actually uninstalling

.EXAMPLE
    .\Uninstall-ScheduledTasks.ps1
    Removes all My-Scripts scheduled tasks
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskPrefix = "MyScripts-"
)

Import-Module "$PSScriptRoot/../src/powershell/modules/Core/Logging/PowerShellLoggingFramework.psm1"
$logger = Initialize-Logger -ScriptName "Uninstall-ScheduledTasks"

Write-LogInfo $logger "Starting scheduled task uninstallation"

# Find all matching tasks
$tasks = Get-ScheduledTask -TaskName "$TaskPrefix*" -ErrorAction SilentlyContinue

if ($tasks.Count -eq 0) {
    Write-Host "No tasks found with prefix '$TaskPrefix'" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($tasks.Count) tasks to uninstall:" -ForegroundColor Cyan
$tasks | ForEach-Object {
    Write-Host "  - $($_.TaskName)"
}
Write-Host ""

$removed = 0

foreach ($task in $tasks) {
    if ($PSCmdlet.ShouldProcess($task.TaskName, "Unregister scheduled task")) {
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
            Write-Host "✓ Removed: $($task.TaskName)" -ForegroundColor Green
            Write-LogInfo $logger "Removed task: $($task.TaskName)"
            $removed++
        }
        catch {
            Write-Host "✗ Failed to remove: $($task.TaskName) - $_" -ForegroundColor Red
            Write-LogError $logger "Failed to remove $($task.TaskName): $_"
        }
    }
}

Write-Host ""
Write-Host "Uninstalled $removed tasks" -ForegroundColor Green
Write-LogInfo $logger "Uninstallation complete. Removed: $removed tasks"
```

### Step 4: Update Documentation (1 hour)

Add to `INSTALLATION.md`:

```markdown
## Scheduled Tasks Setup

My-Scripts includes automated tasks for maintenance and backups.

### Installation

1. **Install all scheduled tasks:**
   ```powershell
   .\scripts\Install-ScheduledTasks.ps1 -ScriptRoot "C:\Users\YourName\Documents\Scripts"
   ```

2. **Preview installation (dry-run):**
   ```powershell
   .\scripts\Install-ScheduledTasks.ps1 -ScriptRoot $PWD -WhatIf
   ```

3. **Force overwrite existing tasks:**
   ```powershell
   .\scripts\Install-ScheduledTasks.ps1 -ScriptRoot $PWD -Force
   ```

### Installed Tasks

| Task Name | Schedule | Description |
|-----------|----------|-------------|
| MyScripts-Monthly System Health Check | Monthly | Comprehensive system diagnostics |
| MyScripts-Postgres Log Cleanup | Daily | Removes old PostgreSQL logs |
| MyScripts-Delete Old Downloads | Weekly | Cleans old download files |
| MyScripts-Drive Space Monitor | Daily | Monitors disk space |
| MyScripts-Clear Old Recycle Bin Items | Weekly | Empties recycle bin |
| MyScripts-PostgreSQL Gnucash Backup | Daily | Backs up GnuCash database |
| MyScripts-PostgreSQL timeline_data Backup | Daily | Backs up timeline database |

### Customization

Edit template files in `config/tasks/*.xml.template` to:
- Change schedules
- Modify task parameters
- Adjust triggers

After editing templates, reinstall tasks with `-Force`.

### Uninstallation

```powershell
.\scripts\Uninstall-ScheduledTasks.ps1
```

### Troubleshooting

**Tasks not running:**
1. Check Task Scheduler Event Log
2. Verify paths are correct
3. Test script manually: `pwsh -File "path\to\script.ps1"`

**Permission errors:**
- Run installation as Administrator
- Check script execution policy: `Set-ExecutionPolicy RemoteSigned`
```

### Step 5: Testing (1 hour)

```powershell
# Test script
$testRoot = "C:\Temp\TestScripts"
New-Item -ItemType Directory -Path $testRoot -Force

# Test installation
.\scripts\Install-ScheduledTasks.ps1 -ScriptRoot $testRoot -WhatIf

# Verify XML generation
$xmlFiles = Get-ChildItem "$testRoot\config\tasks\*.xml"
Write-Host "Generated $($xmlFiles.Count) XML files"

# Verify placeholders replaced
$content = Get-Content $xmlFiles[0].FullName -Raw
if ($content -match '\{\{SCRIPT_ROOT\}\}') {
    Write-Error "Placeholder not replaced!"
}

# Test uninstallation
.\scripts\Uninstall-ScheduledTasks.ps1 -WhatIf

# Cleanup
Remove-Item $testRoot -Recurse -Force
```

---

## Testing Strategy

### Unit Tests
- Template file validation
- Placeholder replacement logic
- XML validation

### Integration Tests
- Install on test Windows VM
- Verify all tasks registered
- Test task execution
- Verify uninstallation

### Manual Testing
1. Test on fresh Windows system
2. Install with various script root paths
3. Verify tasks appear in Task Scheduler
4. Run each task manually
5. Uninstall and verify removal

---

## Related Issues

- ISSUE-008: Fix Hardcoded Paths in Scripts
- ISSUE-009: Fix Hardcoded Paths in Documentation
- ISSUE-005: Create Environment Variable System

---

## References

- Task Scheduler XML Schema: https://docs.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-schema
- Register-ScheduledTask: https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/register-scheduledtask

---

## Success Metrics

- [ ] All 8 XML files converted to templates
- [ ] Installation script works on fresh system
- [ ] All tasks install without errors
- [ ] Generated XMLs have no placeholders
- [ ] Uninstall script removes all tasks
- [ ] Documentation updated with clear instructions
- [ ] Tested on Windows 10/11

---

**Estimated Time Breakdown:**
- Create template files: 1.5 hours
- Create installation script: 2.5 hours
- Create uninstall script: 1 hour
- Update documentation: 1 hour
- Testing and validation: 1 hour
- **Total: 6 hours**
