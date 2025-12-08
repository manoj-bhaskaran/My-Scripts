function Remove-QueueItem {
    <#
    .SYNOPSIS
        Removes a specific item from the queue.

    .DESCRIPTION
        Removes items from the queue based on specified criteria such as file path,
        session ID, or custom filter. This is useful for removing items that no longer
        need processing or that match specific conditions.

    .PARAMETER Queue
        The queue object created by New-FileQueue.

    .PARAMETER FilePath
        Path of the file to remove from the queue. Matches against SourcePath.

    .PARAMETER SessionId
        Session ID to filter items for removal. Only items with this session ID will be removed.

    .PARAMETER FilterScript
        Custom script block to filter items for removal.
        The script block receives each item as $_ and should return $true for items to keep.

    .PARAMETER RemoveAll
        If specified, removes all items from the queue.

    .EXAMPLE
        Remove-QueueItem -Queue $queue -FilePath "C:\temp\file.txt"
        Removes the specified file from the queue.

    .EXAMPLE
        Remove-QueueItem -Queue $queue -SessionId "abc-123"
        Removes all items queued by the specified session.

    .EXAMPLE
        Remove-QueueItem -Queue $queue -FilterScript { $_.Attempts -gt 3 }
        Removes all items that have been attempted more than 3 times.

    .EXAMPLE
        Remove-QueueItem -Queue $queue -RemoveAll
        Clears the entire queue.

    .OUTPUTS
        Int32 - The number of items removed from the queue.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPath')]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByPath')]
        [Parameter(Mandatory = $true, ParameterSetName = 'BySession')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByFilter')]
        [Parameter(Mandatory = $true, ParameterSetName = 'RemoveAll')]
        [ValidateNotNull()]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPath')]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'BySession')]
        [ValidateNotNullOrEmpty()]
        [string]$SessionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByFilter')]
        [ValidateNotNull()]
        [scriptblock]$FilterScript,

        [Parameter(Mandatory = $true, ParameterSetName = 'RemoveAll')]
        [switch]$RemoveAll
    )

    begin {
        Write-Verbose "Removing items from queue: $($Queue.Name)"
    }

    process {
        $initialCount = $Queue.Items.Count
        $removedCount = 0

        try {
            if ($RemoveAll) {
                $removedCount = $initialCount
                $Queue.Clear()
                Write-Verbose "Cleared all $removedCount items from queue"
                return $removedCount
            }

            # Create a temporary array to hold items we want to keep
            $itemsToKeep = @()
            $tempQueue = [System.Collections.Generic.Queue[PSCustomObject]]::new()

            # Process each item in the queue
            while ($Queue.Items.Count -gt 0) {
                $item = $Queue.Dequeue()
                $keepItem = $true

                switch ($PSCmdlet.ParameterSetName) {
                    'ByPath' {
                        if ($item.SourcePath -eq $FilePath) {
                            $keepItem = $false
                            Write-Verbose "Removing item: $($item.SourcePath)"
                        }
                    }
                    'BySession' {
                        if ($item.SessionId -eq $SessionId) {
                            $keepItem = $false
                            Write-Verbose "Removing item from session $SessionId : $($item.SourcePath)"
                        }
                    }
                    'ByFilter' {
                        # FilterScript returns $true for items to KEEP
                        if (-not (& $FilterScript $item)) {
                            $keepItem = $false
                            Write-Verbose "Removing item (filtered): $($item.SourcePath)"
                        }
                    }
                }

                if ($keepItem) {
                    $tempQueue.Enqueue($item)
                }
                else {
                    $removedCount++
                }
            }

            # Restore the queue with kept items
            $Queue.Items = $tempQueue

            Write-Verbose "Removed $removedCount item(s) from queue"
            return $removedCount
        }
        catch {
            Write-Error "Failed to remove items from queue: $_"
            return 0
        }
    }

    end {
        Write-Verbose "Remove-QueueItem completed"
    }
}
