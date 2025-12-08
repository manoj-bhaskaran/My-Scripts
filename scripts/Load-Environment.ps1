<#
.SYNOPSIS
    Loads environment variables from .env file into the current session.
#>

$envFile = Join-Path $PSScriptRoot ".." ".env"

if (-not (Test-Path $envFile)) {
    Write-Warning ".env file not found at: $envFile"
    Write-Information "Copy .env.example to .env and configure your values" -InformationAction Continue
    return
}

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()

    # Skip comments and empty lines
    if ($line -match '^\s*#' -or $line -eq '') {
        return
    }

    # Parse VAR=value
    if ($line -match '^([^=]+)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()

        # Remove surrounding quotes if present
        $value = $value -replace '^["\'']|["\'']$', ''

        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        Write-Verbose "Set $name"
    }
}

Write-Information "Environment loaded from $envFile" -InformationAction Continue
