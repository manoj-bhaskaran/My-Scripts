# FileQueue Module

A PowerShell module for managing file distribution queues with persistence support.

## Overview

The FileQueue module provides a robust, object-oriented queue implementation specifically designed for file distribution operations. It includes features for queue management, state persistence, and metadata tracking.

## Features

- **Queue Management**: Create and manage file queues with configurable size limits
- **Metadata Tracking**: Capture file size, timestamps, and custom metadata
- **State Persistence**: Save and restore queue state across sessions
- **Session Tracking**: Track queue ownership with session identifiers
- **FIFO Processing**: First-in-first-out queue processing
- **Flexible Filtering**: Remove items based on path, session, or custom criteria

## Installation

```powershell
Import-Module /path/to/FileQueue/FileQueue.psd1
```

## Usage

### Creating a Queue

```powershell
# Create a basic queue
$queue = New-FileQueue -Name "DistributionQueue"

# Create a queue with size limit and state persistence
$queue = New-FileQueue -Name "LimitedQueue" -MaxSize 500 -StatePath "C:\temp\queue.json"

# Create an unlimited queue
$queue = New-FileQueue -Name "UnlimitedQueue" -MaxSize -1
```

### Adding Files to Queue

```powershell
# Add a file
Add-FileToQueue -Queue $queue -FilePath "C:\source\file.txt" -TargetPath "D:\target\file.txt"

# Add a file with custom metadata
Add-FileToQueue -Queue $queue -FilePath "C:\file.txt" -Metadata @{Priority=1; Category="Important"}

# Add without file validation (useful for queuing files that will exist later)
Add-FileToQueue -Queue $queue -FilePath "C:\future.txt" -ValidateFile $false
```

### Processing Queue Items

```powershell
# Get and remove next item
$item = Get-NextQueueItem -Queue $queue

# Peek at next item without removing
$item = Get-NextQueueItem -Queue $queue -Peek

# Process all items
while ($queue.Items.Count -gt 0) {
    $item = Get-NextQueueItem -Queue $queue
    # Process the item...
    Copy-Item -Path $item.SourcePath -Destination $item.TargetPath
}
```

### Removing Items

```powershell
# Remove by file path
Remove-QueueItem -Queue $queue -FilePath "C:\temp\file.txt"

# Remove by session ID
Remove-QueueItem -Queue $queue -SessionId "abc-123"

# Remove with custom filter
Remove-QueueItem -Queue $queue -FilterScript { $_.Attempts -gt 3 }

# Clear entire queue
Remove-QueueItem -Queue $queue -RemoveAll
```

### Saving and Restoring State

```powershell
# Save queue state
Save-QueueState -Queue $queue -Force

# Save to custom location
Save-QueueState -Queue $queue -Path "C:\backup\queue.json" -Force

# Restore queue from state file
$queue = Restore-QueueState -Path "C:\temp\queue.json"

# Restore into existing queue
Restore-QueueState -Path "C:\temp\queue.json" -Queue $existingQueue

# Merge restored items with existing queue
Restore-QueueState -Path "C:\temp\queue.json" -Queue $existingQueue -MergeItems
```

## Queue Item Structure

Each queued item contains:

- **SourcePath**: Original file location
- **TargetPath**: Intended destination path
- **Size**: File size in bytes
- **LastWriteTimeUtc**: Last modification time in UTC
- **QueuedAtUtc**: Timestamp when item was queued
- **SessionId**: Session identifier for tracking ownership
- **Attempts**: Number of processing attempts
- **Metadata**: Custom metadata hashtable

## Queue Properties

- **Name**: Queue identifier
- **Items**: Generic.Queue containing queued items
- **MaxSize**: Maximum queue capacity (-1 for unlimited)
- **StatePath**: Path for state persistence
- **SessionId**: Session identifier
- **Created**: Queue creation timestamp
- **Processed**: Count of successfully processed items
- **Failed**: Count of failed items

## Queue Methods

- **Enqueue($Item)**: Add an item to the queue
- **Dequeue()**: Remove and return the next item
- **Peek()**: View the next item without removing it
- **Clear()**: Remove all items from the queue
- **Count()**: Get the number of items in the queue

## Examples

### Basic File Distribution

```powershell
# Create queue
$queue = New-FileQueue -Name "Distribution" -StatePath "queue.json"

# Add files
Get-ChildItem "C:\source" -File | ForEach-Object {
    Add-FileToQueue -Queue $queue -FilePath $_.FullName -TargetPath "D:\target\$($_.Name)"
}

# Process queue
while ($queue.Items.Count -gt 0) {
    $item = Get-NextQueueItem -Queue $queue
    try {
        Copy-Item -Path $item.SourcePath -Destination $item.TargetPath
        $queue.Processed++
    }
    catch {
        Write-Error "Failed to copy $($item.SourcePath): $_"
        $queue.Failed++
    }
}

# Save final state
Save-QueueState -Queue $queue -Force
```

### Resumable Processing

```powershell
# Initial run
$queue = New-FileQueue -Name "LongProcess" -StatePath "state.json"
# ... add items and process some ...
Save-QueueState -Queue $queue -Force

# Resume later
$queue = Restore-QueueState -Path "state.json"
# Continue processing...
```

### Priority Processing with Metadata

```powershell
# Queue files with priorities
Add-FileToQueue -Queue $queue -FilePath "file1.txt" -Metadata @{Priority=1}
Add-FileToQueue -Queue $queue -FilePath "file2.txt" -Metadata @{Priority=5}

# Process high-priority items first (requires custom sorting)
# Note: For true priority queues, consider pre-sorting before adding to queue
```

## Requirements

- PowerShell 5.1 or later
- Write access for state file location (if using persistence)

## Version

1.0.0

## License

Copyright (c) 2025. All rights reserved.
