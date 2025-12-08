function Save-QueueState {
    <#
    .SYNOPSIS
        Saves the queue state to a file for persistence.

    .DESCRIPTION
        Serializes the queue state (items and metadata) to a JSON file for persistence
        across PowerShell sessions. This allows queues to be restored after script
        interruption or for scheduled processing.

    .PARAMETER Queue
        The queue object created by New-FileQueue.

    .PARAMETER Path
        Path where the queue state should be saved.
        If not specified, uses the StatePath property from the queue object.

    .PARAMETER Force
        If specified, overwrites existing state file without prompting.

    .PARAMETER Compress
        If specified, compresses the JSON output to reduce file size.

    .EXAMPLE
        Save-QueueState -Queue $queue
        Saves the queue state to the path specified in the queue's StatePath property.

    .EXAMPLE
        Save-QueueState -Queue $queue -Path "C:\temp\queue-backup.json" -Force
        Saves the queue state to a specific path, overwriting if it exists.

    .OUTPUTS
        Boolean indicating success ($true) or failure ($false).

    .NOTES
        The saved state includes:
        - Queue metadata (name, session ID, statistics)
        - All queued items with their properties
        - Timestamp of when state was saved
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory = $false)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$Compress
    )

    begin {
        Write-Verbose "Saving queue state"
    }

    process {
        # Determine save path
        $savePath = if ([string]::IsNullOrEmpty($Path)) {
            if ([string]::IsNullOrEmpty($Queue.StatePath)) {
                Write-Error "No save path specified and queue has no StatePath configured"
                return $false
            }
            $Queue.StatePath
        }
        else {
            $Path
        }

        # Ensure directory exists
        $directory = Split-Path -Path $savePath -Parent
        if (-not [string]::IsNullOrEmpty($directory) -and -not (Test-Path -Path $directory)) {
            try {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
                Write-Verbose "Created directory: $directory"
            }
            catch {
                Write-Error "Failed to create directory '$directory': $_"
                return $false
            }
        }

        # Check if file exists and handle overwrite
        if ((Test-Path -Path $savePath) -and -not $Force -and -not $PSCmdlet.ShouldProcess($savePath, "Overwrite queue state")) {
            Write-Warning "Queue state file already exists: $savePath. Use -Force to overwrite."
            return $false
        }

        try {
            # Convert queue items to array for serialization
            $itemsArray = @()
            $tempItems = [System.Collections.Generic.Queue[PSCustomObject]]::new()

            # Extract items while preserving queue
            while ($Queue.Items.Count -gt 0) {
                $item = $Queue.Dequeue()
                $itemsArray += $item
                $tempItems.Enqueue($item)
            }

            # Restore queue
            $Queue.Items = $tempItems

            # Create state object
            $state = [PSCustomObject]@{
                Name = $Queue.Name
                SessionId = $Queue.SessionId
                Created = $Queue.Created
                Processed = $Queue.Processed
                Failed = $Queue.Failed
                MaxSize = $Queue.MaxSize
                ItemCount = $itemsArray.Count
                SavedAt = (Get-Date).ToUniversalTime()
                Items = $itemsArray
            }

            # Serialize to JSON
            $jsonDepth = 10
            if ($Compress) {
                $json = $state | ConvertTo-Json -Depth $jsonDepth -Compress
            }
            else {
                $json = $state | ConvertTo-Json -Depth $jsonDepth
            }

            # Save to file
            $json | Set-Content -Path $savePath -Encoding UTF8 -Force

            Write-Verbose "Queue state saved to: $savePath ($($itemsArray.Count) items)"
            return $true
        }
        catch {
            Write-Error "Failed to save queue state to '$savePath': $_"
            return $false
        }
    }

    end {
        Write-Verbose "Save-QueueState completed"
    }
}
