function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes script block with automatic retry on failure using exponential backoff.

    .DESCRIPTION
        Repeatedly attempts to execute a script block with configurable retry logic
        and exponential backoff delay. Useful for transient failures like file locks,
        network issues, or race conditions.

    .PARAMETER Operation
        The script block to execute.

    .PARAMETER Description
        Description of the operation for logging purposes.

    .PARAMETER RetryDelay
        Base delay in seconds before first retry (default: 2).

    .PARAMETER RetryCount
        Maximum number of retry attempts (default: 3).
        Use 0 for unlimited retries (not recommended for production).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 60).

    .PARAMETER LogErrors
        Whether to log retry attempts and errors (default: $true).

    .PARAMETER IgnoreFileNotFound
        When set, treats file-not-found errors as warning-and-skip instead of retrying or throwing.
        This applies to System.Management.Automation.ItemNotFoundException and
        "Cannot find path ... does not exist" error messages.

    .EXAMPLE
        Invoke-WithRetry -Operation {
            Copy-Item $source $dest -Force
        } -Description "Copy file to destination" -RetryCount 5

    .EXAMPLE
        Invoke-WithRetry -Operation {
            Remove-Item $path -Force
        } -Description "Delete temporary file" -RetryDelay 1 -RetryCount 3

    .OUTPUTS
        The result of the script block operation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [int]$RetryCount = 3,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 60,

        [Parameter(Mandatory = $false)]
        [bool]$LogErrors = $true,

        [Parameter(Mandatory = $false)]
        [switch]$IgnoreFileNotFound
    )

    $attempt = 0
    $hasLogger = Get-Command Write-LogWarning -ErrorAction SilentlyContinue
    $hasInfoLogger = Get-Command Write-LogInfo -ErrorAction SilentlyContinue

    while ($true) {
        try {
            $result = & $Operation

            if ($attempt -gt 0 -and $LogErrors) {
                $msg = "Succeeded after $attempt retry attempt(s): $Description"
                if ($hasInfoLogger) {
                    Write-LogInfo $msg
                }
                else {
                    Write-Verbose $msg
                }
            }

            return $result
        }
        catch {
            $exception = $_.Exception
            $err = $_.Exception.Message
            $isFileNotFoundError = $exception -is [System.Management.Automation.ItemNotFoundException] -or
            ($err -like '*Cannot find path*' -and $err -like '*does not exist*')

            if ($IgnoreFileNotFound -and $isFileNotFoundError) {
                $msg = "Skipping operation due to file-not-found condition: $Description. Error: $err"
                if ($hasLogger) {
                    Write-LogWarning $msg
                }
                else {
                    Write-Warning $msg
                }

                return
            }

            $attempt++

            if ($RetryCount -ne 0 -and $attempt -ge $RetryCount) {
                $msg = "Operation failed after $attempt attempt(s): $Description. Error: $err"
                if ($LogErrors) {
                    if ($hasLogger) {
                        Write-LogError $msg
                    }
                    else {
                        Write-Error $msg
                    }
                }
                throw
            }

            $delay = [Math]::Min([int]($RetryDelay * [Math]::Pow(2, $attempt - 1)), $MaxBackoff)

            if ($LogErrors) {
                $msg = "Attempt $attempt failed for $Description. Error: $err. Retrying in $delay second(s)..."
                if ($hasLogger) {
                    Write-LogWarning $msg
                }
                else {
                    Write-Warning $msg
                }
            }

            Start-Sleep -Seconds $delay
        }
    }
}
