# ProgressReporter Module

## Overview

The ProgressReporter module provides standardized progress reporting utilities for PowerShell scripts. It offers consistent progress bar formatting, logging integration, and a tracker object for managing complex multi-stage operations.

## Installation

The module is automatically deployed when using the `Deploy-Modules.ps1` script.

Manual import:
```powershell
Import-Module "$PSScriptRoot/path/to/ProgressReporter.psm1"
```

## Functions

### Show-Progress

Displays a standardized progress indicator using `Write-Progress`.

**Parameters:**
- `Activity` - Description of the activity being performed
- `PercentComplete` - Percentage complete (0-100)
- `Status` - Current status message (optional)
- `Id` - Progress bar ID for nested progress (default: 0)
- `CurrentOperation` - Current operation being performed (optional)
- `Completed` - Mark progress as completed and hide the progress bar

**Example:**
```powershell
Show-Progress -Activity "Processing files" -PercentComplete 50 -Status "50 of 100 files"
Show-Progress -Activity "Processing files" -Completed
```

### Write-ProgressLog

Combines progress reporting with logging. Displays a progress bar and writes a log entry.

**Parameters:**
- `Message` - Progress message to log
- `Current` - Current item number
- `Total` - Total number of items
- `Activity` - Activity description (optional, uses Message if not provided)
- `Id` - Progress bar ID (default: 0)

**Example:**
```powershell
Write-ProgressLog -Message "Processing files" -Current 50 -Total 100

for ($i = 1; $i -le 100; $i++) {
    Write-ProgressLog -Message "Processing file" -Current $i -Total 100
    # Do work...
}
```

### New-ProgressTracker

Creates a progress tracker object for managing progress state across multiple operations.

**Parameters:**
- `Total` - Total number of items to process
- `Activity` - Description of the activity
- `UpdateFrequency` - How often to update progress (every N items, default: 1)

**Returns:** Hashtable progress tracker object

**Example:**
```powershell
$progress = New-ProgressTracker -Total 1000 -Activity "Processing files" -UpdateFrequency 10
```

### Update-ProgressTracker

Updates a progress tracker and displays progress if needed.

**Parameters:**
- `Tracker` - Progress tracker object from `New-ProgressTracker`
- `Increment` - Amount to increment (default: 1)
- `Force` - Force update even if UpdateFrequency threshold not met
- `Status` - Optional status message

**Example:**
```powershell
Update-ProgressTracker -Tracker $progress -Increment 1
Update-ProgressTracker -Tracker $progress -Status "Processing file.txt" -Force
```

### Complete-ProgressTracker

Marks a progress tracker as completed, shows 100% and hides the progress bar.

**Parameters:**
- `Tracker` - Progress tracker object from `New-ProgressTracker`
- `FinalMessage` - Optional final message to display

**Example:**
```powershell
Complete-ProgressTracker -Tracker $progress
Complete-ProgressTracker -Tracker $progress -FinalMessage "Processing complete"
```

### Write-ProgressStatus

Updates the CurrentOperation field of the progress bar without changing the percentage.

**Parameters:**
- `Activity` - Activity description
- `Status` - Current status
- `Id` - Progress bar ID (default: 0)

**Example:**
```powershell
Write-ProgressStatus -Activity "Processing files" -Status "Copying file.txt"
```

## Usage Patterns

### Simple Progress Loop

```powershell
Import-Module ProgressReporter

$files = Get-ChildItem "C:\data" -File
$total = $files.Count

for ($i = 0; $i -lt $total; $i++) {
    $percent = [int](($i / $total) * 100)
    Show-Progress -Activity "Processing files" -PercentComplete $percent -Status "$i of $total"

    # Process file
    Process-File $files[$i]
}

Show-Progress -Activity "Processing files" -Completed
```

### Progress with Logging

```powershell
Import-Module ProgressReporter

$items = 1..100

foreach ($i in $items) {
    Write-ProgressLog -Message "Processing item" -Current $i -Total $items.Count

    # Do work
    Start-Sleep -Milliseconds 100
}
```

### Advanced Progress Tracker

```powershell
Import-Module ProgressReporter

# Create tracker for 1000 items, update every 50 items
$tracker = New-ProgressTracker -Total 1000 -Activity "Processing large dataset" -UpdateFrequency 50

foreach ($item in 1..1000) {
    # Process item
    Process-Item $item

    # Update progress (only shows every 50 items)
    Update-ProgressTracker -Tracker $tracker -Increment 1

    # Force update for important milestones
    if ($item -eq 500) {
        Update-ProgressTracker -Tracker $tracker -Status "Halfway complete!" -Force
    }
}

Complete-ProgressTracker -Tracker $tracker -FinalMessage "All items processed successfully"
```

### Nested Progress Bars

```powershell
Import-Module ProgressReporter

$folders = Get-ChildItem "C:\data" -Directory

for ($i = 0; $i -lt $folders.Count; $i++) {
    $folder = $folders[$i]

    # Outer progress bar (ID = 0)
    Show-Progress -Activity "Processing folders" -PercentComplete (($i / $folders.Count) * 100) -Id 0

    $files = Get-ChildItem $folder.FullName -File

    for ($j = 0; $j -lt $files.Count; $j++) {
        # Inner progress bar (ID = 1)
        Show-Progress -Activity "Processing files in $($folder.Name)" -PercentComplete (($j / $files.Count) * 100) -Id 1

        # Process file
        Process-File $files[$j]
    }

    # Hide inner progress bar
    Show-Progress -Activity "Processing files" -Completed -Id 1
}

# Hide outer progress bar
Show-Progress -Activity "Processing folders" -Completed -Id 0
```

## Migration Guide

### Before (Manual Progress)
```powershell
$files = Get-ChildItem "C:\data"
$total = $files.Count
$current = 0

foreach ($file in $files) {
    $current++
    $percent = [int](($current / $total) * 100)
    Write-Progress -Activity "Processing files" -PercentComplete $percent -Status "$current of $total"
    Process-File $file
}

Write-Progress -Activity "Processing files" -Completed
```

### After (Using ProgressReporter)
```powershell
Import-Module ProgressReporter

$files = Get-ChildItem "C:\data"
$tracker = New-ProgressTracker -Total $files.Count -Activity "Processing files"

foreach ($file in $files) {
    Process-File $file
    Update-ProgressTracker -Tracker $tracker
}

Complete-ProgressTracker -Tracker $tracker
```

### Before (Progress with Logging)
```powershell
$current = 0
$total = 100

foreach ($i in 1..100) {
    $current++
    $percent = [int](($current / $total) * 100)
    $msg = "Processing item $current of $total (${percent}%)"
    Write-Log $msg
    Write-Progress -Activity "Processing" -PercentComplete $percent
}
```

### After (Using ProgressReporter)
```powershell
Import-Module ProgressReporter

foreach ($i in 1..100) {
    Write-ProgressLog -Message "Processing item" -Current $i -Total 100
}
```

## Integration with Logging

The module automatically integrates with the `PowerShellLoggingFramework` module if available. When using `Write-ProgressLog`, log entries are written using `Write-LogInfo` if the logging framework is loaded. Otherwise, it falls back to `Write-Verbose`.

## Performance Considerations

For large datasets (10,000+ items), use the `UpdateFrequency` parameter in `New-ProgressTracker` to reduce the overhead of updating the progress bar:

```powershell
# Update progress every 100 items instead of every item
$tracker = New-ProgressTracker -Total 100000 -Activity "Processing" -UpdateFrequency 100
```

This significantly reduces the performance impact of progress reporting.

## Version History

### 1.0.0 (2025-11-20)
- Initial release
- `Show-Progress` function
- `Write-ProgressLog` function
- `New-ProgressTracker` function
- `Update-ProgressTracker` function
- `Complete-ProgressTracker` function
- `Write-ProgressStatus` function
- Integration with PowerShellLoggingFramework
- Support for nested progress bars

## License

Apache License 2.0
