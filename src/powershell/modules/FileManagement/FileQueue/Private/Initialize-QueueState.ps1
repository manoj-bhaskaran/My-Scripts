function Initialize-QueueState {
    <#
    .SYNOPSIS
        Initializes queue state structure for persistence.

    .DESCRIPTION
        Internal helper function that creates a properly formatted queue state object
        for serialization and persistence. Used by Save-QueueState to ensure
        consistent state structure.

    .PARAMETER Queue
        The queue object to initialize state for.

    .PARAMETER IncludeItems
        If specified, includes all queue items in the state.
        Default is $true.

    .EXAMPLE
        $state = Initialize-QueueState -Queue $queue
        Creates a state object for the queue.

    .OUTPUTS
        PSCustomObject representing the queue state structure.

    .NOTES
        This is a private function used internally by the FileQueue module.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeItems = $true
    )

    begin {
        Write-Verbose "Initializing queue state structure"
    }

    process {
        try {
            $state = [PSCustomObject]@{
                Name = $Queue.Name
                SessionId = $Queue.SessionId
                Created = $Queue.Created
                Processed = $Queue.Processed
                Failed = $Queue.Failed
                MaxSize = $Queue.MaxSize
                ItemCount = $Queue.Items.Count
                LastStateUpdate = (Get-Date).ToUniversalTime()
            }

            if ($IncludeItems) {
                # Convert queue to array for state
                $itemsArray = @()
                $tempQueue = [System.Collections.Generic.Queue[PSCustomObject]]::new()

                while ($Queue.Items.Count -gt 0) {
                    $item = $Queue.Dequeue()
                    $itemsArray += $item
                    $tempQueue.Enqueue($item)
                }

                # Restore queue
                $Queue.Items = $tempQueue

                # Add items to state
                Add-Member -InputObject $state -MemberType NoteProperty -Name 'Items' -Value $itemsArray
            }

            return $state
        }
        catch {
            Write-Error "Failed to initialize queue state: $_"
            return $null
        }
    }

    end {
        Write-Verbose "Queue state initialization completed"
    }
}
