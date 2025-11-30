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
