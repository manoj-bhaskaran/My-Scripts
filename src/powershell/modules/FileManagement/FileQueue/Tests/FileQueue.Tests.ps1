# FileQueue.Tests.ps1 - Pester tests for FileQueue module

BeforeAll {
    # Import the module
    $ModulePath = Split-Path -Path $PSScriptRoot -Parent
    Import-Module "$ModulePath\FileQueue.psd1" -Force
}

Describe "FileQueue Module" {
    Context "New-FileQueue" {
        It "Creates empty queue with default settings" {
            $queue = New-FileQueue -Name "TestQueue"
            $queue.Items.Count | Should -Be 0
            $queue.Name | Should -Be "TestQueue"
            $queue.MaxSize | Should -Be 10000
            $queue.SessionId | Should -Not -BeNullOrEmpty
        }

        It "Creates queue with custom max size" {
            $queue = New-FileQueue -Name "SmallQueue" -MaxSize 100
            $queue.MaxSize | Should -Be 100
        }

        It "Creates queue with unlimited size" {
            $queue = New-FileQueue -Name "UnlimitedQueue" -MaxSize -1
            $queue.MaxSize | Should -Be -1
        }

        It "Creates queue with custom session ID" {
            $sessionId = [guid]::NewGuid().ToString()
            $queue = New-FileQueue -Name "CustomSession" -SessionId $sessionId
            $queue.SessionId | Should -Be $sessionId
        }

        It "Creates queue with state path" {
            $statePath = "TestDrive:\queue-state.json"
            $queue = New-FileQueue -Name "StateQueue" -StatePath $statePath
            $queue.StatePath | Should -Be $statePath
        }

        It "Queue has required properties" {
            $queue = New-FileQueue -Name "TestQueue"
            $queue.PSObject.Properties.Name | Should -Contain 'Name'
            $queue.PSObject.Properties.Name | Should -Contain 'Items'
            $queue.PSObject.Properties.Name | Should -Contain 'MaxSize'
            $queue.PSObject.Properties.Name | Should -Contain 'SessionId'
            $queue.PSObject.Properties.Name | Should -Contain 'Created'
            $queue.PSObject.Properties.Name | Should -Contain 'Processed'
            $queue.PSObject.Properties.Name | Should -Contain 'Failed'
        }

        It "Queue has required methods" {
            $queue = New-FileQueue -Name "TestQueue"
            $queue.PSObject.Methods.Name | Should -Contain 'Enqueue'
            $queue.PSObject.Methods.Name | Should -Contain 'Dequeue'
            $queue.PSObject.Methods.Name | Should -Contain 'Peek'
            $queue.PSObject.Methods.Name | Should -Contain 'Clear'
        }
    }

    Context "Add-FileToQueue" {
        BeforeEach {
            $queue = New-FileQueue -Name "TestQueue"
        }

        It "Adds valid file to queue" {
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file

            $result = Add-FileToQueue -Queue $queue -FilePath $file
            $result | Should -Be $true
            $queue.Items.Count | Should -Be 1
        }

        It "Records file metadata correctly" {
            $file = "TestDrive:\test.txt"
            "test content" | Out-File -FilePath $file

            Add-FileToQueue -Queue $queue -FilePath $file -TargetPath "TestDrive:\target.txt"

            $item = Get-NextQueueItem -Queue $queue
            $item.SourcePath | Should -Be $file
            $item.TargetPath | Should -Be "TestDrive:\target.txt"
            $item.Size | Should -BeGreaterThan 0
            $item.SessionId | Should -Be $queue.SessionId
            $item.Attempts | Should -Be 1
        }

        It "Stores custom metadata" {
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file

            $metadata = @{Priority = 1; Category = "Important"}
            Add-FileToQueue -Queue $queue -FilePath $file -Metadata $metadata

            $item = Get-NextQueueItem -Queue $queue
            $item.Metadata.Priority | Should -Be 1
            $item.Metadata.Category | Should -Be "Important"
        }

        It "Returns false for non-existent file" {
            $result = Add-FileToQueue -Queue $queue -FilePath "TestDrive:\nonexistent.txt"
            $result | Should -Be $false
        }

        It "Can queue file without validation" {
            $result = Add-FileToQueue -Queue $queue -FilePath "TestDrive:\nonexistent.txt" -ValidateFile $false
            $result | Should -Be $true
            $queue.Items.Count | Should -Be 1
        }

        It "Enforces max size limit" {
            $smallQueue = New-FileQueue -Name "Small" -MaxSize 2

            $file1 = "TestDrive:\file1.txt"
            $file2 = "TestDrive:\file2.txt"
            $file3 = "TestDrive:\file3.txt"
            "content" | Out-File -FilePath $file1
            "content" | Out-File -FilePath $file2
            "content" | Out-File -FilePath $file3

            Add-FileToQueue -Queue $smallQueue -FilePath $file1 | Should -Be $true
            Add-FileToQueue -Queue $smallQueue -FilePath $file2 | Should -Be $true
            Add-FileToQueue -Queue $smallQueue -FilePath $file3 | Should -Be $false
        }

        It "Unlimited queue accepts many items" {
            $unlimitedQueue = New-FileQueue -Name "Unlimited" -MaxSize -1

            for ($i = 1; $i -le 100; $i++) {
                $file = "TestDrive:\file$i.txt"
                "content" | Out-File -FilePath $file
                Add-FileToQueue -Queue $unlimitedQueue -FilePath $file | Should -Be $true
            }

            $unlimitedQueue.Items.Count | Should -Be 100
        }
    }

    Context "Get-NextQueueItem" {
        BeforeEach {
            $queue = New-FileQueue -Name "TestQueue"
        }

        It "Returns null for empty queue" {
            $item = Get-NextQueueItem -Queue $queue
            $item | Should -BeNullOrEmpty
        }

        It "Dequeues item from queue" {
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file

            Add-FileToQueue -Queue $queue -FilePath $file
            $initialCount = $queue.Items.Count

            $item = Get-NextQueueItem -Queue $queue
            $item.SourcePath | Should -Be $file
            $queue.Items.Count | Should -Be ($initialCount - 1)
        }

        It "Peeks at item without removing" {
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file

            Add-FileToQueue -Queue $queue -FilePath $file
            $initialCount = $queue.Items.Count

            $item = Get-NextQueueItem -Queue $queue -Peek
            $item.SourcePath | Should -Be $file
            $queue.Items.Count | Should -Be $initialCount
        }

        It "Increments attempts counter" {
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file

            Add-FileToQueue -Queue $queue -FilePath $file

            $item = Get-NextQueueItem -Queue $queue -IncrementAttempts $true
            $item.Attempts | Should -Be 1
        }

        It "Does not increment attempts when disabled" {
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file

            Add-FileToQueue -Queue $queue -FilePath $file

            $item = Get-NextQueueItem -Queue $queue -IncrementAttempts $false
            $item.Attempts | Should -Be 0
        }

        It "Processes queue in FIFO order" {
            $file1 = "TestDrive:\file1.txt"
            $file2 = "TestDrive:\file2.txt"
            $file3 = "TestDrive:\file3.txt"
            "content" | Out-File -FilePath $file1
            "content" | Out-File -FilePath $file2
            "content" | Out-File -FilePath $file3

            Add-FileToQueue -Queue $queue -FilePath $file1
            Add-FileToQueue -Queue $queue -FilePath $file2
            Add-FileToQueue -Queue $queue -FilePath $file3

            $item1 = Get-NextQueueItem -Queue $queue
            $item2 = Get-NextQueueItem -Queue $queue
            $item3 = Get-NextQueueItem -Queue $queue

            $item1.SourcePath | Should -Be $file1
            $item2.SourcePath | Should -Be $file2
            $item3.SourcePath | Should -Be $file3
        }
    }

    Context "Remove-QueueItem" {
        BeforeEach {
            $queue = New-FileQueue -Name "TestQueue"
        }

        It "Removes item by file path" {
            $file1 = "TestDrive:\file1.txt"
            $file2 = "TestDrive:\file2.txt"
            "content" | Out-File -FilePath $file1
            "content" | Out-File -FilePath $file2

            Add-FileToQueue -Queue $queue -FilePath $file1
            Add-FileToQueue -Queue $queue -FilePath $file2

            $removed = Remove-QueueItem -Queue $queue -FilePath $file1
            $removed | Should -Be 1
            $queue.Items.Count | Should -Be 1
        }

        It "Removes items by session ID" {
            $file1 = "TestDrive:\file1.txt"
            $file2 = "TestDrive:\file2.txt"
            "content" | Out-File -FilePath $file1
            "content" | Out-File -FilePath $file2

            $otherSession = [guid]::NewGuid().ToString()

            Add-FileToQueue -Queue $queue -FilePath $file1
            Add-FileToQueue -Queue $queue -FilePath $file2 -ValidateFile $false

            # Manually set different session ID for second item
            $tempItems = [System.Collections.Generic.Queue[PSCustomObject]]::new()
            $item1 = $queue.Dequeue()
            $item2 = $queue.Dequeue()
            $item2.SessionId = $otherSession
            $tempItems.Enqueue($item1)
            $tempItems.Enqueue($item2)
            $queue.Items = $tempItems

            $removed = Remove-QueueItem -Queue $queue -SessionId $otherSession
            $removed | Should -Be 1
            $queue.Items.Count | Should -Be 1
        }

        It "Removes items by filter script" {
            for ($i = 1; $i -le 5; $i++) {
                $file = "TestDrive:\file$i.txt"
                "content" | Out-File -FilePath $file
                Add-FileToQueue -Queue $queue -FilePath $file -Metadata @{Priority = $i}
            }

            # Remove items with priority > 3
            $removed = Remove-QueueItem -Queue $queue -FilterScript { $_.Metadata.Priority -le 3 }
            $removed | Should -Be 2
            $queue.Items.Count | Should -Be 3
        }

        It "Clears all items with RemoveAll" {
            for ($i = 1; $i -le 10; $i++) {
                $file = "TestDrive:\file$i.txt"
                "content" | Out-File -FilePath $file
                Add-FileToQueue -Queue $queue -FilePath $file
            }

            $removed = Remove-QueueItem -Queue $queue -RemoveAll
            $removed | Should -Be 10
            $queue.Items.Count | Should -Be 0
        }
    }

    Context "Save-QueueState and Restore-QueueState" {
        BeforeEach {
            $queue = New-FileQueue -Name "TestQueue" -StatePath "TestDrive:\queue-state.json"
        }

        It "Saves queue state to file" {
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file
            Add-FileToQueue -Queue $queue -FilePath $file

            $result = Save-QueueState -Queue $queue -Force
            $result | Should -Be $true
            Test-Path "TestDrive:\queue-state.json" | Should -Be $true
        }

        It "Restores queue state from file" {
            $file1 = "TestDrive:\file1.txt"
            $file2 = "TestDrive:\file2.txt"
            "content" | Out-File -FilePath $file1
            "content" | Out-File -FilePath $file2

            Add-FileToQueue -Queue $queue -FilePath $file1
            Add-FileToQueue -Queue $queue -FilePath $file2

            Save-QueueState -Queue $queue -Force

            $restoredQueue = Restore-QueueState -Path "TestDrive:\queue-state.json"
            $restoredQueue | Should -Not -BeNullOrEmpty
            $restoredQueue.Items.Count | Should -Be 2
            $restoredQueue.Name | Should -Be "TestQueue"
        }

        It "Preserves metadata during save/restore" {
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file

            $metadata = @{Priority = 1; Type = "Test"}
            Add-FileToQueue -Queue $queue -FilePath $file -Metadata $metadata

            Save-QueueState -Queue $queue -Force
            $restoredQueue = Restore-QueueState -Path "TestDrive:\queue-state.json"

            $item = Get-NextQueueItem -Queue $restoredQueue
            $item.Metadata.Priority | Should -Be 1
            $item.Metadata.Type | Should -Be "Test"
        }

        It "Saves to custom path" {
            $customPath = "TestDrive:\custom-queue.json"
            $file = "TestDrive:\test.txt"
            "content" | Out-File -FilePath $file

            Add-FileToQueue -Queue $queue -FilePath $file

            $result = Save-QueueState -Queue $queue -Path $customPath -Force
            $result | Should -Be $true
            Test-Path $customPath | Should -Be $true
        }

        It "Restores into existing queue" {
            $file1 = "TestDrive:\file1.txt"
            $file2 = "TestDrive:\file2.txt"
            "content" | Out-File -FilePath $file1
            "content" | Out-File -FilePath $file2

            Add-FileToQueue -Queue $queue -FilePath $file1
            Save-QueueState -Queue $queue -Force

            $newQueue = New-FileQueue -Name "NewQueue"
            Add-FileToQueue -Queue $newQueue -FilePath $file2

            $result = Restore-QueueState -Path "TestDrive:\queue-state.json" -Queue $newQueue
            $result.Items.Count | Should -Be 1
        }

        It "Merges items when MergeItems is specified" {
            $file1 = "TestDrive:\file1.txt"
            $file2 = "TestDrive:\file2.txt"
            "content" | Out-File -FilePath $file1
            "content" | Out-File -FilePath $file2

            Add-FileToQueue -Queue $queue -FilePath $file1
            Save-QueueState -Queue $queue -Force

            $newQueue = New-FileQueue -Name "NewQueue"
            Add-FileToQueue -Queue $newQueue -FilePath $file2

            $result = Restore-QueueState -Path "TestDrive:\queue-state.json" -Queue $newQueue -MergeItems
            $result.Items.Count | Should -Be 2
        }
    }

    Context "Queue Statistics" {
        It "Tracks processed and failed counts" {
            $queue = New-FileQueue -Name "TestQueue"
            $queue.Processed | Should -Be 0
            $queue.Failed | Should -Be 0

            # These are manually updated by calling code
            $queue.Processed = 5
            $queue.Failed = 2

            $queue.Processed | Should -Be 5
            $queue.Failed | Should -Be 2
        }
    }

    Context "Edge Cases and Error Handling" {
        It "Handles queue with no state path configured" {
            $queue = New-FileQueue -Name "NoStatePath"
            $result = Save-QueueState -Queue $queue
            $result | Should -Be $false
        }

        It "Handles non-existent restore file" {
            $result = Restore-QueueState -Path "TestDrive:\nonexistent.json"
            $result | Should -BeNullOrEmpty
        }

        It "Handles empty queue save/restore" {
            $queue = New-FileQueue -Name "EmptyQueue" -StatePath "TestDrive:\empty.json"
            Save-QueueState -Queue $queue -Force

            $restored = Restore-QueueState -Path "TestDrive:\empty.json"
            $restored.Items.Count | Should -Be 0
        }
    }
}

AfterAll {
    # Clean up
    Remove-Module FileQueue -ErrorAction SilentlyContinue
}
