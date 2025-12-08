function Get-NextQueueItem {
    <#
    .SYNOPSIS
        Retrieves the next item from the queue.

    .DESCRIPTION
        Gets the next item from the queue for processing. Can either peek at the item
        (without removing it) or dequeue it (remove from queue).

    .PARAMETER Queue
        The queue object created by New-FileQueue.

    .PARAMETER Peek
        If specified, returns the next item without removing it from the queue.
        Default is $false (dequeue the item).

    .PARAMETER IncrementAttempts
        If specified and dequeuing, increments the Attempts counter on the item.
        Default is $true.

    .EXAMPLE
        $item = Get-NextQueueItem -Queue $queue
        Retrieves and removes the next item from the queue.

    .EXAMPLE
        $item = Get-NextQueueItem -Queue $queue -Peek
        Views the next item without removing it from the queue.

    .OUTPUTS
        PSCustomObject representing the queue item, or $null if queue is empty.
        The item contains:
        - SourcePath: Original file location
        - TargetPath: Intended destination
        - Size: File size in bytes
        - LastWriteTimeUtc: Last modification time
        - QueuedAtUtc: Time when item was queued
        - SessionId: Session identifier
        - Attempts: Number of processing attempts
        - Metadata: Custom metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory = $false)]
        [switch]$Peek,

        [Parameter(Mandatory = $false)]
        [bool]$IncrementAttempts = $true
    )

    begin {
        Write-Verbose "Getting next queue item (Peek: $Peek)"
    }

    process {
        if ($Queue.Items.Count -eq 0) {
            Write-Verbose "Queue is empty"
            return $null
        }

        $item = $null

        try {
            if ($Peek) {
                $item = $Queue.Peek()
            }
            else {
                $item = $Queue.Dequeue()

                # Increment attempts counter if requested and not peeking
                if ($IncrementAttempts -and $null -ne $item) {
                    $item.Attempts++
                }
            }

            if ($null -ne $item) {
                Write-Verbose "Retrieved item: $($item.SourcePath)"
            }

            return $item
        }
        catch {
            Write-Error "Failed to get next queue item: $_"
            return $null
        }
    }

    end {
        Write-Verbose "Get-NextQueueItem completed"
    }
}
