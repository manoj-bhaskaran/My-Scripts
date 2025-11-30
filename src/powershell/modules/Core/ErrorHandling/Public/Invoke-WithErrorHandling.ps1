function Invoke-WithErrorHandling {
    <#
    .SYNOPSIS
        Executes script block with standardized error handling.

    .DESCRIPTION
        Wraps a script block in try/catch with configurable error handling behavior
        and optional logging integration.

    .PARAMETER ScriptBlock
        Code to execute.

    .PARAMETER OnError
        Action to take on error. Valid values:
        - Stop: Re-throw the exception (default)
        - Continue: Return $null and continue
        - SilentlyContinue: Return $null silently

    .PARAMETER LogError
        Whether to log error using Write-LogError if available (default: $true).

    .PARAMETER ErrorMessage
        Custom error message prefix. If not provided, uses the exception message.

    .EXAMPLE
        Invoke-WithErrorHandling {
            Get-Content "file.txt"
        } -OnError Stop

    .EXAMPLE
        $result = Invoke-WithErrorHandling {
            $data = Get-Content "optional-file.txt"
            return $data
        } -OnError Continue -ErrorMessage "Failed to read optional file"

    .OUTPUTS
        The result of the script block, or $null if an error occurs and OnError is not 'Stop'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stop', 'Continue', 'SilentlyContinue')]
        [string]$OnError = 'Stop',

        [Parameter(Mandatory = $false)]
        [bool]$LogError = $true,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = $null
    )

    try {
        & $ScriptBlock
    }
    catch {
        $errMsg = if ($ErrorMessage) {
            "$ErrorMessage : $($_.Exception.Message)"
        }
        else {
            "Error: $($_.Exception.Message)"
        }

        # Handle logging based on OnError setting
        if ($LogError) {
            switch ($OnError) {
                'Stop' {
                    # Log as error
                    if (Get-Command Write-LogError -ErrorAction SilentlyContinue) {
                        Write-LogError $errMsg
                    }
                    else {
                        Write-Error $errMsg -ErrorAction Continue
                    }
                }
                'Continue' {
                    # Log as warning for Continue
                    if (Get-Command Write-LogWarning -ErrorAction SilentlyContinue) {
                        Write-LogWarning $errMsg
                    }
                    else {
                        Write-Warning $errMsg
                    }
                }
                'SilentlyContinue' {
                    # Don't log anything for SilentlyContinue
                }
            }
        }

        switch ($OnError) {
            'Stop' { throw }
            'Continue' { return $null }
            'SilentlyContinue' { return $null }
        }
    }
}
