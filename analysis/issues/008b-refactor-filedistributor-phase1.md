# Issue #008b: Refactor FileDistributor - Extract Queue Logic

**Parent Issue**: [#008: Large Complex Scripts](./008-large-complex-scripts.md)
**Phase**: Phase 2 - FileDistributor Refactoring
**Effort**: 8 hours

## Description
Extract queue management logic from FileDistributor.ps1 (2,747 lines) into a separate module. This is step 1 of breaking down the monolithic script.

## Scope
Extract from FileDistributor.ps1:
- Queue initialization
- Item queueing
- Queue state management
- Queue persistence

## Implementation

### Module Structure
```
src/powershell/modules/FileManagement/FileQueue/
├── FileQueue.psd1
├── FileQueue.psm1
├── Public/
│   ├── New-FileQueue.ps1
│   ├── Add-FileToQueue.ps1
│   ├── Get-NextQueueItem.ps1
│   ├── Remove-QueueItem.ps1
│   └── Save-QueueState.ps1
└── Private/
    ├── Initialize-QueueState.ps1
    └── Update-QueueMetrics.ps1
```

### New-FileQueue.ps1
```powershell
function New-FileQueue {
    <#
    .SYNOPSIS
        Creates a new file distribution queue.

    .PARAMETER Name
        Queue name

    .PARAMETER MaxSize
        Maximum queue size
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [int]$MaxSize = 1000,

        [string]$StatePath
    )

    $queue = [PSCustomObject]@{
        Name = $Name
        Items = [System.Collections.Generic.Queue[PSCustomObject]]::new()
        MaxSize = $MaxSize
        StatePath = $StatePath
        Created = Get-Date
        Processed = 0
        Failed = 0
    }

    Add-Member -InputObject $queue -MemberType ScriptMethod -Name 'Enqueue' -Value {
        param($Item)
        if ($this.Items.Count -ge $this.MaxSize) {
            throw "Queue is full (max: $($this.MaxSize))"
        }
        $this.Items.Enqueue($Item)
    }

    Add-Member -InputObject $queue -MemberType ScriptMethod -Name 'Dequeue' -Value {
        if ($this.Items.Count -eq 0) {
            return $null
        }
        return $this.Items.Dequeue()
    }

    return $queue
}
```

### Add-FileToQueue.ps1
```powershell
function Add-FileToQueue {
    <#
    .SYNOPSIS
        Adds a file to the distribution queue.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [string]$TargetPath,

        [hashtable]$Metadata = @{}
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $false
    }

    $fileInfo = Get-Item -Path $FilePath
    $queueItem = [PSCustomObject]@{
        SourcePath = $FilePath
        TargetPath = $TargetPath
        Size = $fileInfo.Length
        LastModified = $fileInfo.LastWriteTimeUtc
        QueuedAt = Get-Date
        Attempts = 0
        Metadata = $Metadata
    }

    try {
        $Queue.Enqueue($queueItem)
        Write-Verbose "Queued: $FilePath"
        return $true
    }
    catch {
        Write-Error "Failed to queue file: $_"
        return $false
    }
}
```

## Testing
```powershell
Describe "FileQueue Module" {
    Context "New-FileQueue" {
        It "Creates empty queue" {
            $queue = New-FileQueue -Name "TestQueue"
            $queue.Items.Count | Should -Be 0
            $queue.Name | Should -Be "TestQueue"
        }

        It "Enforces max size" {
            $queue = New-FileQueue -Name "Small" -MaxSize 2

            Add-FileToQueue -Queue $queue -FilePath "TestDrive:/file1.txt"
            Add-FileToQueue -Queue $queue -FilePath "TestDrive:/file2.txt"

            { Add-FileToQueue -Queue $queue -FilePath "TestDrive:/file3.txt" } |
                Should -Throw
        }
    }

    Context "Add-FileToQueue" {
        It "Adds valid file to queue" {
            $queue = New-FileQueue -Name "Test"
            $file = "TestDrive:/test.txt"
            "content" | Out-File $file

            Add-FileToQueue -Queue $queue -FilePath $file

            $queue.Items.Count | Should -Be 1
        }

        It "Records file metadata" {
            $queue = New-FileQueue -Name "Test"
            $file = "TestDrive:/test.txt"
            "content" | Out-File $file

            Add-FileToQueue -Queue $queue -FilePath $file -Metadata @{Priority=1}

            $item = $queue.Dequeue()
            $item.Metadata.Priority | Should -Be 1
            $item.Size | Should -BeGreaterThan 0
        }
    }
}
```

## Migration from FileDistributor.ps1
```powershell
# Before (inline queue management)
$script:fileQueue = @()
$script:fileQueue += @{Path=$file; Target=$target}

# After (using module)
Import-Module FileQueue
$script:queue = New-FileQueue -Name "Distribution"
Add-FileToQueue -Queue $script:queue -FilePath $file -TargetPath $target
```

## Acceptance Criteria
- [ ] FileQueue module created and tested
- [ ] Queue operations properly encapsulated
- [ ] State persistence supported
- [ ] FileDistributor.ps1 updated to use module
- [ ] Line count of FileDistributor.ps1 reduced by ~300 lines
- [ ] All existing functionality preserved
- [ ] Tests achieve 70%+ coverage

## Benefits
- Isolated queue logic
- Reusable for other scripts
- Easier to test
- Reduces FileDistributor complexity
- Step toward full refactoring

## Effort
8 hours

## Next Steps
- Issue #008c: Extract retry logic
- Issue #008d: Extract file movement logic
