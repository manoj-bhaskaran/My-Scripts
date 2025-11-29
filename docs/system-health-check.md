# Monthly System Health Check

> **Note:** Examples in this guide use placeholder paths like `<SCRIPT_ROOT>`.
> Replace `<SCRIPT_ROOT>` with your actual script directory (e.g., `C:\Users\YourName\Documents\Scripts` on Windows).
> See [Documentation Placeholders](conventions/placeholders.md) for more information.

## Overview

The Monthly System Health Check is an automated solution for maintaining Windows system integrity through regular scheduled maintenance. This feature runs critical Windows system repair tools on a monthly basis and captures detailed logs for review.

## Features

- **Automated Monthly Execution**: Scheduled task runs on the 1st of each month at 2:00 AM
- **System File Checker (SFC)**: Scans and repairs corrupted Windows system files
- **DISM Restore Health**: Repairs the Windows component store and system image
- **Comprehensive Logging**: All output is captured in timestamped log files
- **Administrator Privileges**: Runs with elevated permissions automatically
- **Detailed Status Reports**: Includes duration tracking, exit codes, and summary information

## Components

### 1. Invoke-SystemHealthCheck.ps1

The main script that performs the health checks.

**Location**: `src/powershell/Invoke-SystemHealthCheck.ps1`

**Features**:
- Validates Administrator privileges before execution
- Checks available disk space (warns if less than 5GB free)
- Runs SFC and DISM sequentially
- Captures all output with timestamps
- Provides detailed execution summary
- References additional Windows log locations

**Parameters**:
- `-LogFolder`: Location for log files (default: `D:\SystemHealth\logs`)

**Example Usage**:
```powershell
# Run with default settings
.\Invoke-SystemHealthCheck.ps1

# Run with custom log folder
.\Invoke-SystemHealthCheck.ps1 -LogFolder "C:\Logs\SystemHealth"
```

### 2. Install-SystemHealthCheckTask.ps1

Setup script for creating the scheduled task.

**Location**: `src/powershell/Install-SystemHealthCheckTask.ps1`

**Features**:
- Auto-detects script location
- Creates scheduled task with optimal settings
- Validates prerequisites
- Provides detailed installation feedback
- Allows customization of schedule and settings

**Parameters**:
- `-ScriptPath`: Path to Invoke-SystemHealthCheck.ps1 (auto-detected if not provided)
- `-LogFolder`: Log folder location (default: `D:\SystemHealth\logs`)
- `-TaskName`: Name of the scheduled task (default: "Monthly System Health Check")
- `-RunDay`: Day of month to run (1-31, default: 1)
- `-RunTime`: Time to run in 24-hour format (default: "02:00")

**Example Usage**:
```powershell
# Install with default settings
.\Install-SystemHealthCheckTask.ps1

# Install with custom schedule
.\Install-SystemHealthCheckTask.ps1 -RunDay 15 -RunTime "03:00" -LogFolder "C:\Logs"
```

### 3. Monthly System Health Check.xml

Pre-configured Windows Task Scheduler XML file.

**Location**: `Windows Task Scheduler/Monthly System Health Check.xml`

This file can be imported directly into Task Scheduler if you prefer manual import over using the installation script.

## Installation

### Method 1: Automated Installation (Recommended)

1. Open PowerShell as Administrator
2. Navigate to the repository folder
3. Run the installation script:

```powershell
cd "<SCRIPT_ROOT>"
.\src\powershell\Install-SystemHealthCheckTask.ps1
```

The script will:
- Verify Administrator privileges
- Auto-detect script locations
- Create the log folder
- Register the scheduled task
- Display confirmation and next steps

### Method 2: Manual Task Scheduler Import

1. Open Task Scheduler (`Win+R`, type `taskschd.msc`)
2. Click **Action > Import Task**
3. Browse to `Windows Task Scheduler/Monthly System Health Check.xml`
4. Update the script path in the Actions tab if needed
5. Update the user account in the General tab
6. Click OK and enter your password when prompted

### Method 3: Manual PowerShell Task Creation

You can also create the task manually using PowerShell:

```powershell
# Create the scheduled task components
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"C:\Path\To\Invoke-SystemHealthCheck.ps1`""

$trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At "02:00"

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Password -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun

# Register the task
Register-ScheduledTask -TaskName "Monthly System Health Check" `
    -Action $action -Trigger $trigger -Principal $principal -Settings $settings
```

## Usage

### Running the Task Manually

To test the task before waiting for the scheduled run:

```powershell
# Option 1: Using Task Scheduler
Start-ScheduledTask -TaskName "Monthly System Health Check"

# Option 2: Running the script directly (as Administrator)
.\src\powershell\Invoke-SystemHealthCheck.ps1
```

### Viewing Logs

Logs are saved with timestamps in the format: `SystemHealthCheck_YYYYMMDD_HHMMSS.log`

**Default Location**: `D:\SystemHealth\logs\`

**Log Contents**:
- Execution start/end times
- System drive and free space information
- Complete SFC output
- Complete DISM output
- Exit codes for both operations
- Execution duration for each step
- Overall summary and status

**Additional Windows Logs**:
- CBS Log: `%SystemRoot%\Logs\CBS\CBS.log`
- DISM Log: `%SystemRoot%\Logs\DISM\dism.log`

### Viewing Task Status

```powershell
# Get task information
Get-ScheduledTask -TaskName "Monthly System Health Check"

# Get task history
Get-ScheduledTask -TaskName "Monthly System Health Check" | Get-ScheduledTaskInfo

# View last run result
(Get-ScheduledTask -TaskName "Monthly System Health Check" | Get-ScheduledTaskInfo).LastRunTime
(Get-ScheduledTask -TaskName "Monthly System Health Check" | Get-ScheduledTaskInfo).LastTaskResult
```

## Customization

### Changing the Schedule

To modify when the task runs:

```powershell
# Uninstall existing task
Unregister-ScheduledTask -TaskName "Monthly System Health Check" -Confirm:$false

# Reinstall with new schedule
.\Install-SystemHealthCheckTask.ps1 -RunDay 15 -RunTime "03:00"
```

### Changing the Log Location

Edit the `-LogFolder` parameter when installing or running the script:

```powershell
# During installation
.\Install-SystemHealthCheckTask.ps1 -LogFolder "C:\CustomPath\Logs"

# When running manually
.\Invoke-SystemHealthCheck.ps1 -LogFolder "C:\CustomPath\Logs"
```

### Modifying Task Settings

You can edit the task directly in Task Scheduler:

1. Open Task Scheduler
2. Navigate to **Task Scheduler Library**
3. Right-click **Monthly System Health Check**
4. Select **Properties**
5. Modify settings as needed (triggers, actions, conditions, settings)

## Troubleshooting

### Task Not Running

**Check Task Status**:
```powershell
Get-ScheduledTask -TaskName "Monthly System Health Check"
```

Ensure `State` is `Ready`, not `Disabled`.

**Check Task History**:
1. Open Task Scheduler
2. Enable history: **Action > Enable All Tasks History**
3. Select the task and click the **History** tab

### Insufficient Permissions

The script requires Administrator privileges. Ensure:
- The task is configured to run with highest privileges
- The LogonType is set to `Password` or `Interactive`
- Your account has Administrator rights

### Low Disk Space

DISM operations require at least 5GB of free disk space. The script will warn you if space is low but will still attempt to run.

**Check disk space**:
```powershell
Get-PSDrive C | Select-Object Used,Free
```

### Script Not Found

If the scheduled task reports "file not found":
1. Open Task Scheduler
2. Edit the task
3. Go to the **Actions** tab
4. Verify the script path is correct
5. Update if necessary

### Reviewing Failures

If SFC or DISM fail:

1. **Check the generated log file** in your log folder
2. **Review CBS.log**: `%SystemRoot%\Logs\CBS\CBS.log`
3. **Review DISM.log**: `%SystemRoot%\Logs\DISM\dism.log`
4. **Common issues**:
   - Insufficient disk space
   - Windows Update service not running
   - Corrupted component store requiring additional repair steps

## Uninstallation

To remove the scheduled task:

```powershell
Unregister-ScheduledTask -TaskName "Monthly System Health Check" -Confirm:$false
```

The scripts and log files will remain on disk. You can manually delete them if desired.

## System Requirements

- **Operating System**: Windows 7 or later
- **PowerShell**: 5.1 or later
- **Privileges**: Administrator rights required
- **Disk Space**: At least 5GB free space recommended for DISM operations
- **Services**: Windows Update service should be running for DISM operations

## Exit Codes

The `Invoke-SystemHealthCheck.ps1` script returns the following exit codes:

- **0**: Both SFC and DISM completed successfully
- **1**: Script completed but one or both tools reported warnings/errors
- **2**: Critical script error (exception occurred)

When run as a scheduled task, these codes are available in Task Scheduler history.

## Best Practices

1. **Review logs monthly**: Check the logs after each run to ensure system health
2. **Maintain disk space**: Keep at least 10GB free on the system drive
3. **Keep Windows updated**: Apply Windows updates regularly for best results
4. **Test initially**: Run the task manually after installation to verify it works
5. **Backup first**: Consider taking a system backup before the first run
6. **Monitor duration**: SFC and DISM can take 30-60 minutes combined; schedule accordingly

## FAQ

**Q: How long does the health check take?**
A: Typically 30-60 minutes total. SFC usually takes 15-30 minutes, and DISM takes 20-45 minutes. Duration varies based on system size and issues found.

**Q: Will this fix all Windows problems?**
A: SFC and DISM repair many common system file and component store issues, but not all problems. For persistent issues, additional troubleshooting may be needed.

**Q: Can I run this more frequently than monthly?**
A: Yes, but it's generally unnecessary. Monthly maintenance is sufficient for most systems. You can adjust the schedule during installation.

**Q: What if the task wakes my computer at night?**
A: The task is configured with `WakeToRun` enabled. If you don't want this, edit the task in Task Scheduler and disable the "Wake the computer to run this task" option in the Conditions tab.

**Q: Do I need to be logged in for the task to run?**
A: No, the task is configured to run whether you're logged in or not (using Password LogonType).

**Q: Can I run this on a laptop?**
A: Yes. The task is configured to run even on battery power to ensure maintenance happens regularly.

## Related Links

- [System File Checker (SFC) Documentation](https://support.microsoft.com/en-us/topic/use-the-system-file-checker-tool-to-repair-missing-or-corrupted-system-files-79aa86cb-ca52-166a-92a3-966e85d4094e)
- [DISM Documentation](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/what-is-dism)
- [Windows Task Scheduler Documentation](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page)

## Version History

- **1.0.0** (2025-11-16): Initial release
  - Monthly scheduled system health checks
  - SFC and DISM execution with logging
  - Automated installation script
  - Comprehensive documentation

## Support

For issues or questions:
- Open an issue in the GitHub repository
- Check the troubleshooting section above
- Review the generated log files for detailed error information
