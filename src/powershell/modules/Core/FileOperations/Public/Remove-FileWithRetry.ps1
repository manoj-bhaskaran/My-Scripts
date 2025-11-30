function Remove-FileWithRetry {
    <#
    .SYNOPSIS
        Removes a file with automatic retry on failure.

    .DESCRIPTION
        Deletes a file with built-in retry logic to handle locked files.

    .PARAMETER Path
        Path to the file to remove.

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 2).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 60).

    .EXAMPLE
        Remove-FileWithRetry -Path "C:\\temp\\file.txt"

    .OUTPUTS
        [bool] True if removal succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 60
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Path does not exist: $Path"
        return $true
    }

    $operation = {
        Remove-Item -Path $Path -Force -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
            -Description "Remove '$Path'" `
            -RetryDelay $RetryDelay `
            -RetryCount $MaxRetries `
            -MaxBackoff $MaxBackoff
    }
    else {
        & $operation
    }

    return $true
}
