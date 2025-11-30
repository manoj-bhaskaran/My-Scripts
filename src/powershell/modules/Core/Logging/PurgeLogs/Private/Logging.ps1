function Write-LogMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Level,
        [Parameter(Mandatory)]
        [string]$Message,
        [hashtable]$Metadata = @{}
    )

    $levelMap = @{
        'DEBUG'   = 'Write-LogDebug'
        'INFO'    = 'Write-LogInfo'
        'WARNING' = 'Write-LogWarning'
        'ERROR'   = 'Write-LogError'
        'CRITICAL'= 'Write-LogCritical'
    }

    $commandName = $levelMap[$Level]
    if ($commandName -and (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        & $commandName -Message $Message -Metadata $Metadata
    }
    else {
        Write-Verbose $Message
    }
}
