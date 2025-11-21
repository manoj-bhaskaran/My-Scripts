############################################################
# ErrorHandling.psm1
# Standardized error handling utilities
############################################################

<#
.SYNOPSIS
    Provides standardized error handling and privilege checking utilities.

.DESCRIPTION
    This module provides reusable functions for error handling, retry logic,
    and elevation (admin/sudo) detection across PowerShell scripts.

.NOTES
    Version: 1.0.0
    Date: 2025-11-20
    License: Apache License, Version 2.0
#>

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
        } else {
            "Error: $($_.Exception.Message)"
        }

        # Handle logging based on OnError setting
        if ($LogError) {
            switch ($OnError) {
                'Stop' {
                    # Log as error
                    if (Get-Command Write-LogError -ErrorAction SilentlyContinue) {
                        Write-LogError $errMsg
                    } else {
                        Write-Error $errMsg -ErrorAction Continue
                    }
                }
                'Continue' {
                    # Log as warning for Continue
                    if (Get-Command Write-LogWarning -ErrorAction SilentlyContinue) {
                        Write-LogWarning $errMsg
                    } else {
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
        [bool]$LogErrors = $true
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
                } else {
                    Write-Verbose $msg
                }
            }

            return $result
        }
        catch {
            $attempt++
            $err = $_.Exception.Message

            if ($RetryCount -ne 0 -and $attempt -ge $RetryCount) {
                $msg = "Operation failed after $attempt attempt(s): $Description. Error: $err"
                if ($LogErrors) {
                    if ($hasLogger) {
                        Write-LogError $msg
                    } else {
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
                } else {
                    Write-Warning $msg
                }
            }

            Start-Sleep -Seconds $delay
        }
    }
}

function Test-IsElevated {
    <#
    .SYNOPSIS
        Checks if script is running with elevated privileges.

    .DESCRIPTION
        Determines if the current PowerShell session is running with administrator
        privileges on Windows or root privileges on Linux/macOS.

    .EXAMPLE
        if (Test-IsElevated) {
            Write-Host "Running with admin privileges"
        }

    .OUTPUTS
        [bool] True if running with elevated privileges, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Check if running on Windows
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = [Security.Principal.WindowsPrincipal]$identity
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            Write-Warning "Failed to check Windows elevation status: $_"
            return $false
        }
    }
    else {
        # Linux/macOS: check if running as root (UID 0)
        try {
            $uid = & id -u
            return ($uid -eq 0)
        }
        catch {
            Write-Warning "Failed to check Unix elevation status: $_"
            return $false
        }
    }
}

function Assert-Elevated {
    <#
    .SYNOPSIS
        Throws an exception if script is not running with elevated privileges.

    .DESCRIPTION
        Validates that the current session has administrator (Windows) or root
        (Linux/macOS) privileges. Throws a terminating error if not elevated.

    .PARAMETER CustomMessage
        Optional custom error message. If not provided, uses a default message.

    .EXAMPLE
        Assert-Elevated
        # Script continues only if running as admin/root

    .EXAMPLE
        Assert-Elevated -CustomMessage "This operation requires administrator rights"

    .OUTPUTS
        None. Throws if not elevated.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CustomMessage = $null
    )

    if (-not (Test-IsElevated)) {
        $defaultMessage = "This script requires elevated privileges. Run as Administrator (Windows) or with sudo (Linux/macOS)."
        $errorMessage = if ($CustomMessage) { $CustomMessage } else { $defaultMessage }

        throw $errorMessage
    }
}

function Test-CommandAvailable {
    <#
    .SYNOPSIS
        Checks if a command or cmdlet is available in the current session.

    .DESCRIPTION
        Tests whether a command, function, cmdlet, or external executable is available
        for use in the current PowerShell session.

    .PARAMETER CommandName
        Name of the command to test.

    .EXAMPLE
        if (Test-CommandAvailable "git") {
            Write-Host "Git is available"
        }

    .OUTPUTS
        [bool] True if command is available, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-WithErrorHandling',
    'Invoke-WithRetry',
    'Test-IsElevated',
    'Assert-Elevated',
    'Test-CommandAvailable'
)
