function New-FileQueue {
    <#
    .SYNOPSIS
        Creates a new file distribution queue.

    .DESCRIPTION
        Initializes a new file queue with configurable size limits and optional state persistence.
        The queue stores file metadata including path, size, timestamps, and session information.

    .PARAMETER Name
        The name of the queue for identification purposes.

    .PARAMETER MaxSize
        Maximum number of items the queue can hold. Default is 10000.
        Set to -1 for unlimited size.

    .PARAMETER StatePath
        Optional path to save queue state for persistence across sessions.

    .PARAMETER SessionId
        Optional session identifier for tracking queue ownership.
        If not provided, a new GUID will be generated.

    .EXAMPLE
        $queue = New-FileQueue -Name "DistributionQueue"
        Creates a new queue with default settings.

    .EXAMPLE
        $queue = New-FileQueue -Name "LimitedQueue" -MaxSize 500 -StatePath "C:\temp\queue.json"
        Creates a queue with a maximum size of 500 items and enables state persistence.

    .OUTPUTS
        PSCustomObject representing the queue with properties:
        - Name: Queue name
        - Items: Generic.Queue[PSCustomObject] containing queued items
        - MaxSize: Maximum queue capacity
        - StatePath: Path for state persistence (if configured)
        - SessionId: Session identifier
        - Created: Queue creation timestamp
        - Processed: Count of successfully processed items
        - Failed: Count of failed items
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [ValidateRange(-1, [int]::MaxValue)]
        [int]$MaxSize = 10000,

        [Parameter(Mandatory = $false)]
        [string]$StatePath,

        [Parameter(Mandatory = $false)]
        [string]$SessionId
    )

    begin {
        Write-Verbose "Creating new file queue: $Name"
    }

    process {
        # Generate session ID if not provided
        if ([string]::IsNullOrEmpty($SessionId)) {
            $SessionId = [guid]::NewGuid().ToString()
        }

        # Create the queue object
        $queue = [PSCustomObject]@{
            Name = $Name
            Items = [System.Collections.Generic.Queue[PSCustomObject]]::new()
            MaxSize = $MaxSize
            StatePath = $StatePath
            SessionId = $SessionId
            Created = (Get-Date).ToUniversalTime()
            Processed = 0
            Failed = 0
        }

        # Add methods to the queue object
        Add-Member -InputObject $queue -MemberType ScriptMethod -Name 'Enqueue' -Value {
            param($Item)
            if ($this.MaxSize -ne -1 -and $this.Items.Count -ge $this.MaxSize) {
                throw "Queue '$($this.Name)' is full (max: $($this.MaxSize))"
            }
            $this.Items.Enqueue($Item)
        }

        Add-Member -InputObject $queue -MemberType ScriptMethod -Name 'Dequeue' -Value {
            if ($this.Items.Count -eq 0) {
                return $null
            }
            return $this.Items.Dequeue()
        }

        Add-Member -InputObject $queue -MemberType ScriptMethod -Name 'Peek' -Value {
            if ($this.Items.Count -eq 0) {
                return $null
            }
            return $this.Items.Peek()
        }

        Add-Member -InputObject $queue -MemberType ScriptMethod -Name 'Clear' -Value {
            $this.Items.Clear()
        }

        Add-Member -InputObject $queue -MemberType ScriptMethod -Name 'Count' -Value {
            return $this.Items.Count
        }

        Write-Verbose "Queue '$Name' created with SessionId: $SessionId"
        return $queue
    }

    end {
        Write-Verbose "Queue creation completed"
    }
}
