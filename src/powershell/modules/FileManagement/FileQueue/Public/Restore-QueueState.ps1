function Restore-QueueState {
    <#
    .SYNOPSIS
        Restores a queue from a saved state file.

    .DESCRIPTION
        Deserializes a queue from a previously saved JSON state file.
        Can either create a new queue or restore into an existing queue object.

    .PARAMETER Path
        Path to the saved queue state file.

    .PARAMETER Queue
        Optional existing queue object to restore into.
        If not provided, a new queue will be created.

    .PARAMETER MergeItems
        If specified and a Queue is provided, merges items from saved state with existing queue items.
        Default is $false (replaces existing items).

    .EXAMPLE
        $queue = Restore-QueueState -Path "C:\temp\queue-state.json"
        Restores a queue from a saved state file.

    .EXAMPLE
        Restore-QueueState -Path "C:\temp\queue-state.json" -Queue $existingQueue
        Restores state into an existing queue object.

    .OUTPUTS
        PSCustomObject representing the restored queue, or $null on failure.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory = $false)]
        [switch]$MergeItems
    )

    begin {
        Write-Verbose "Restoring queue state from: $Path"
    }

    process {
        # Validate file exists
        if (-not (Test-Path -Path $Path)) {
            Write-Error "Queue state file not found: $Path"
            return $null
        }

        try {
            # Load and deserialize state
            $json = Get-Content -Path $Path -Raw -Encoding UTF8
            $state = $json | ConvertFrom-Json

            # Create or update queue
            if ($null -eq $Queue) {
                # Create new queue
                $Queue = New-FileQueue -Name $state.Name -MaxSize $state.MaxSize -StatePath $Path -SessionId $state.SessionId

                # Restore metadata
                $Queue.Created = $state.Created
                $Queue.Processed = $state.Processed
                $Queue.Failed = $state.Failed
            }
            else {
                # Update existing queue if not merging
                if (-not $MergeItems) {
                    $Queue.Clear()
                }
            }

            # Restore items
            $restoredCount = 0
            foreach ($item in $state.Items) {
                try {
                    # Normalize item to ensure all expected properties exist
                    $normalizedItem = [PSCustomObject]@{
                        SourcePath = $item.SourcePath
                        TargetPath = $item.TargetPath
                        Size = $item.Size
                        LastWriteTimeUtc = if ($item.PSObject.Properties.Name -contains 'LastWriteTimeUtc') {
                            $item.LastWriteTimeUtc
                        }
                        else {
                            $null
                        }
                        QueuedAtUtc = if ($item.PSObject.Properties.Name -contains 'QueuedAtUtc') {
                            $item.QueuedAtUtc
                        }
                        else {
                            (Get-Date).ToUniversalTime()
                        }
                        SessionId = if ($item.PSObject.Properties.Name -contains 'SessionId') {
                            $item.SessionId
                        }
                        else {
                            $Queue.SessionId
                        }
                        Attempts = if ($item.PSObject.Properties.Name -contains 'Attempts') {
                            $item.Attempts
                        }
                        else {
                            0
                        }
                        Metadata = if ($item.PSObject.Properties.Name -contains 'Metadata') {
                            $item.Metadata
                        }
                        else {
                            @{}
                        }
                    }

                    $Queue.Enqueue($normalizedItem)
                    $restoredCount++
                }
                catch {
                    Write-Warning "Failed to restore queue item '$($item.SourcePath)': $_"
                }
            }

            Write-Verbose "Restored $restoredCount item(s) from state file"
            return $Queue
        }
        catch {
            Write-Error "Failed to restore queue state from '$Path': $_"
            return $null
        }
    }

    end {
        Write-Verbose "Restore-QueueState completed"
    }
}
