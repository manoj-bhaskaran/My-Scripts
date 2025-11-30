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
