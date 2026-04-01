# RetryOps.ps1 - General-purpose retry helper and I/O wrappers for FileDistributor module

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)][ScriptBlock]$Operation,
        [Parameter(Mandatory = $true)][string]$Description,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60
    )
    $attempt = 0
    while ($true) {
        try {
            & $Operation
            if ($attempt -gt 0) {
                Write-LogInfo "Succeeded after $attempt retry attempt(s): $Description"
            }
            return
        }
        catch {
            $attempt++
            $err = $_.Exception.Message

            # Check if this is a "file not found" error - handle gracefully without crashing
            $isFileNotFound = ($err -match "Cannot find path" -and $err -match "does not exist") -or
            ($_.Exception -is [System.Management.Automation.ItemNotFoundException])

            if ($isFileNotFound) {
                Write-LogWarning "File not found (skipping): $Description. Error: $err"
                return
            }

            if ($RetryCount -ne 0 -and $attempt -ge $RetryCount) {
                Write-LogError "Operation failed after $attempt attempt(s): $Description. Error: $err"
                throw
            }
            $delay = [Math]::Min([int]($RetryDelay * [Math]::Pow(2, $attempt - 1)), $MaxBackoff)
            Write-LogWarning "Attempt $attempt failed for $Description. Error: $err. Retrying in $delay second(s)..."
            Start-Sleep -Seconds $delay
        }
    }
}

function Copy-ItemWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Destination,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60
    )
    Invoke-WithRetry -Operation { Copy-Item -Path $Path -Destination $Destination -Force -ErrorAction Stop } `
        -Description "Copy '$Path' -> '$Destination'" -MaxBackoff $MaxBackoff `
        -RetryDelay $RetryDelay -RetryCount $RetryCount
}

function Remove-ItemWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60
    )
    Invoke-WithRetry -Operation { Remove-Item -Path $Path -Force -ErrorAction Stop } `
        -Description "Delete '$Path'" -MaxBackoff $MaxBackoff `
        -RetryDelay $RetryDelay -RetryCount $RetryCount
}

function Rename-ItemWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$NewName,
        [int]$RetryDelay = 10,
        [int]$RetryCount = 3,
        [int]$MaxBackoff = 60
    )
    Invoke-WithRetry -Operation { Rename-Item -LiteralPath $Path -NewName $NewName -Force -ErrorAction Stop } `
        -Description "Rename '$Path' -> '$NewName'" -MaxBackoff $MaxBackoff `
        -RetryDelay $RetryDelay -RetryCount $RetryCount
}
