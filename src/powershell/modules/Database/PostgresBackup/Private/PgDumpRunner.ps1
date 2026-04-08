function Invoke-PgDump {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    & $pg_dump_path @ArgumentList *>&1 | Add-Content -Path $LogFilePath -Encoding utf8
}
