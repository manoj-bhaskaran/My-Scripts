function Add-ContentWithRetry {
    <#
    .SYNOPSIS
        Appends content to a file with retry logic.

    .DESCRIPTION
        Appends text content to a file with automatic retry on failure.
        Useful for logging scenarios where file might be temporarily locked.

    .PARAMETER Path
        Path to the file.

    .PARAMETER Value
        Content to append.

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 1).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 30).

    .PARAMETER Encoding
        File encoding (default: UTF8).

    .EXAMPLE
        Add-ContentWithRetry -Path "C:\\logs\\app.log" -Value "Log entry"

    .OUTPUTS
        [bool] True if append succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 1,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 30,

        [Parameter(Mandatory = $false)]
        [string]$Encoding = "UTF8"
    )

    # Ensure parent directory exists
    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    $operation = {
        Add-Content -Path $Path -Value $Value -Encoding $Encoding -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
            -Description "Append content to '$Path'" `
            -RetryDelay $RetryDelay `
            -RetryCount $MaxRetries `
            -MaxBackoff $MaxBackoff `
            -LogErrors $false
    }
    else {
        & $operation
    }

    return $true
}
