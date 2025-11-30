function Move-FileWithRetry {
    <#
    .SYNOPSIS
        Moves a file with automatic retry on failure.

    .DESCRIPTION
        Moves a file from source to destination with built-in retry logic.

    .PARAMETER Source
        Source file path (must exist).

    .PARAMETER Destination
        Destination file path.

    .PARAMETER Force
        Overwrite destination file if it exists (default: $true).

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 2).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 60).

    .EXAMPLE
        Move-FileWithRetry -Source "C:\\temp\\file.txt" -Destination "D:\\archive\\file.txt"

    .OUTPUTS
        [bool] True if move succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $false)]
        [switch]$Force = $true,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 60
    )

    if (-not (Test-Path $Source)) {
        throw "Source file not found: $Source"
    }

    # Ensure destination directory exists
    $destDir = Split-Path -Path $Destination -Parent
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
    }

    $operation = {
        Move-Item -Path $Source -Destination $Destination -Force:$Force -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
            -Description "Move '$Source' to '$Destination'" `
            -RetryDelay $RetryDelay `
            -RetryCount $MaxRetries `
            -MaxBackoff $MaxBackoff
    }
    else {
        & $operation
    }

    return $true
}
