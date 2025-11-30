function Rename-FileWithRetry {
    <#
    .SYNOPSIS
        Renames a file with automatic retry on failure.

    .DESCRIPTION
        Renames a file with built-in retry logic.

    .PARAMETER Path
        Path to the file to rename.

    .PARAMETER NewName
        New name for the file (not full path, just the name).

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 2).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 60).

    .EXAMPLE
        Rename-FileWithRetry -Path "C:\\temp\\oldname.txt" -NewName "newname.txt"

    .OUTPUTS
        [bool] True if rename succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$NewName,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 60
    )

    if (-not (Test-Path $Path)) {
        throw "Path does not exist: $Path"
    }

    $operation = {
        Rename-Item -Path $Path -NewName $NewName -Force -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
            -Description "Rename '$Path' to '$NewName'" `
            -RetryDelay $RetryDelay `
            -RetryCount $MaxRetries `
            -MaxBackoff $MaxBackoff
    }
    else {
        & $operation
    }

    return $true
}
