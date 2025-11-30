function Copy-FileWithRetry {
    <#
    .SYNOPSIS
        Copies a file with automatic retry on failure.

    .DESCRIPTION
        Copies a file from source to destination with built-in retry logic
        to handle transient failures like file locks or network issues.

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
        Copy-FileWithRetry -Source "C:\\source\\file.txt" -Destination "D:\\dest\\file.txt"

    .EXAMPLE
        Copy-FileWithRetry -Source $src -Destination $dst -MaxRetries 5 -RetryDelay 1

    .OUTPUTS
        [bool] True if copy succeeded, throws on failure.
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
        Copy-Item -Path $Source -Destination $Destination -Force:$Force -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
            -Description "Copy '$Source' to '$Destination'" `
            -RetryDelay $RetryDelay `
            -RetryCount $MaxRetries `
            -MaxBackoff $MaxBackoff
    }
    else {
        # Fallback if ErrorHandling module not available
        & $operation
    }

    return $true
}
