function Update-QueueMetrics {
    <#
    .SYNOPSIS
        Updates queue performance metrics.

    .DESCRIPTION
        Internal helper function that updates queue statistics such as processed
        count, failed count, and other metrics. Used after queue operations
        to maintain accurate statistics.

    .PARAMETER Queue
        The queue object to update metrics for.

    .PARAMETER Operation
        The type of operation performed: 'Processed', 'Failed', 'Reset'

    .PARAMETER Count
        Number to add to the metric counter. Default is 1.

    .EXAMPLE
        Update-QueueMetrics -Queue $queue -Operation 'Processed'
        Increments the processed counter by 1.

    .EXAMPLE
        Update-QueueMetrics -Queue $queue -Operation 'Failed' -Count 3
        Increments the failed counter by 3.

    .OUTPUTS
        Boolean indicating success ($true) or failure ($false).

    .NOTES
        This is a private function used internally by the FileQueue module.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Processed', 'Failed', 'Reset')]
        [string]$Operation,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Count = 1
    )

    begin {
        Write-Verbose "Updating queue metrics: $Operation ($Count)"
    }

    process {
        try {
            switch ($Operation) {
                'Processed' {
                    $Queue.Processed += $Count
                    Write-Verbose "Processed count updated to: $($Queue.Processed)"
                }
                'Failed' {
                    $Queue.Failed += $Count
                    Write-Verbose "Failed count updated to: $($Queue.Failed)"
                }
                'Reset' {
                    $Queue.Processed = 0
                    $Queue.Failed = 0
                    Write-Verbose "Metrics reset"
                }
            }

            return $true
        }
        catch {
            Write-Error "Failed to update queue metrics: $_"
            return $false
        }
    }

    end {
        Write-Verbose "Queue metrics update completed"
    }
}
