function Wait-ServiceStatus {
    param (
        [string]$ServiceName,
        [string]$DesiredStatus,
        [int]$MaxWaitTime,
        [int]$PollSeconds,
        [string]$LogFilePath
    )

    $elapsedTime = 0
    while ((Get-Service -Name $ServiceName).Status -ne $DesiredStatus -and $elapsedTime -lt $MaxWaitTime) {
        Start-Sleep -Seconds $PollSeconds
        $elapsedTime += $PollSeconds
    }
    if ((Get-Service -Name $ServiceName).Status -ne $DesiredStatus) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Add-Content -Path $LogFilePath -Value "[$timestamp] Service $ServiceName did not reach $DesiredStatus status within the maximum wait time of $MaxWaitTime seconds." -Encoding utf8
        throw "Service $ServiceName did not reach $DesiredStatus status within the maximum wait time of $MaxWaitTime seconds."
    }
}
