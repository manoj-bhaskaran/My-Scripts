function Add-FileToQueue {
    <#
    .SYNOPSIS
        Adds a file to the distribution queue.

    .DESCRIPTION
        Adds a file with its metadata to the queue for processing. Captures file size,
        modification time, and custom metadata. Validates file existence before queuing.

    .PARAMETER Queue
        The queue object created by New-FileQueue.

    .PARAMETER FilePath
        Path to the file to be queued. Must exist and be accessible.

    .PARAMETER TargetPath
        Optional target destination path for the file.

    .PARAMETER Metadata
        Optional hashtable of custom metadata to associate with the queued file.

    .PARAMETER ValidateFile
        If specified, validates that the file exists before queuing.
        Default is $true.

    .EXAMPLE
        Add-FileToQueue -Queue $queue -FilePath "C:\source\file.txt" -TargetPath "D:\target\file.txt"
        Adds a file to the queue with source and target paths.

    .EXAMPLE
        Add-FileToQueue -Queue $queue -FilePath "C:\file.txt" -Metadata @{Priority=1; Category="Important"}
        Adds a file with custom metadata.

    .OUTPUTS
        Boolean indicating success ($true) or failure ($false).

    .NOTES
        The function captures file metadata at queue time, including:
        - SourcePath: Original file location
        - TargetPath: Intended destination
        - Size: File size in bytes
        - LastWriteTimeUtc: Last modification time in UTC
        - QueuedAtUtc: Time when item was queued in UTC
        - SessionId: Session identifier from the queue
        - Attempts: Number of processing attempts (initialized to 0)
        - Metadata: Custom metadata provided by caller
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]$Queue,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$TargetPath,

        [Parameter(Mandatory = $false)]
        [hashtable]$Metadata = @{},

        [Parameter(Mandatory = $false)]
        [bool]$ValidateFile = $true
    )

    begin {
        Write-Verbose "Adding file to queue: $FilePath"
    }

    process {
        # Validate file exists if requested
        if ($ValidateFile -and -not (Test-Path -LiteralPath $FilePath)) {
            Write-Error "File not found: $FilePath"
            return $false
        }

        # Capture file metadata
        $queuedSize = $null
        $queuedMtimeUtc = $null

        try {
            if (Test-Path -LiteralPath $FilePath) {
                $fileInfo = Get-Item -LiteralPath $FilePath -ErrorAction Stop
                $queuedSize = $fileInfo.Length
                $queuedMtimeUtc = $fileInfo.LastWriteTimeUtc
            }
        }
        catch {
            Write-Warning "Failed to get file info for '$FilePath': $_"
            # Continue with null metadata rather than failing
        }

        # Create queue item with metadata
        $queueItem = [PSCustomObject]@{
            SourcePath = $FilePath
            TargetPath = $TargetPath
            Size = $queuedSize
            LastWriteTimeUtc = $queuedMtimeUtc
            QueuedAtUtc = (Get-Date).ToUniversalTime()
            SessionId = $Queue.SessionId
            Attempts = 0
            Metadata = $Metadata
        }

        # Add to queue
        try {
            $Queue.Enqueue($queueItem)
            Write-Verbose "Successfully queued: $FilePath (Size: $queuedSize bytes)"
            return $true
        }
        catch {
            Write-Error "Failed to queue file '$FilePath': $_"
            return $false
        }
    }

    end {
        Write-Verbose "Add-FileToQueue completed"
    }
}
