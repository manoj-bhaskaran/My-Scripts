[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$Strict
)

function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Failure { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "! $Message" -ForegroundColor Yellow }

$envFile = Join-Path $PSScriptRoot ".." ".env"
if (Test-Path $envFile) {
    Write-Info "Loading variables from $envFile"
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) {
            return
        }

        if ($line -match '^([^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim() -replace '^["\'']|["\'']$', ''
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}
else {
    Write-Warn "No .env file found at $envFile (skipping auto-load)"
}

Write-Info "Verifying Environment Configuration..."
Write-Host ""

$allValid = $true

$requiredVars = @{
    'MY_SCRIPTS_ROOT' = @{
        Description  = 'Script root directory'
        Validator    = { param($v) Test-Path $v }
        ErrorMessage = 'Path does not exist'
    }
}

$optionalVars = @{
    'LOG_LEVEL'             = @{
        Description  = 'Logging level'
        Default      = 'INFO'
        Validator    = { param($v) $v -in @('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL') }
        ErrorMessage = 'Must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL'
    }
    'LOG_DIR'               = @{
        Description = 'Log directory'
        Default     = './logs'
    }
    'BACKUP_RETENTION_DAYS' = @{
        Description  = 'Backup retention days'
        Default      = '30'
        Validator    = { param($v) [int]$v -gt 0 }
        ErrorMessage = 'Must be positive integer'
    }
    'PGHOST'                = @{
        Description = 'PostgreSQL host'
        Default     = 'localhost'
    }
    'PGPORT'                = @{
        Description  = 'PostgreSQL port'
        Default      = '5432'
        Validator    = { param($v) [int]$v -ge 1 -and [int]$v -le 65535 }
        ErrorMessage = 'Must be valid port number (1-65535)'
    }
}

Write-Host "Required Variables:" -ForegroundColor Yellow
foreach ($varName in $requiredVars.Keys) {
    $config = $requiredVars[$varName]
    $value = [Environment]::GetEnvironmentVariable($varName)

    if (-not $value) {
        Write-Failure "$varName - $($config.Description) - NOT SET"
        $allValid = $false
    }
    elseif ($config.Validator -and -not (& $config.Validator $value)) {
        Write-Failure "$varName - $($config.Description) - $($config.ErrorMessage): $value"
        $allValid = $false
    }
    else {
        Write-Success "$varName - $($config.Description) - $value"
    }
}

Write-Host "" 
Write-Host "Optional Variables:" -ForegroundColor Yellow
foreach ($varName in $optionalVars.Keys) {
    $config = $optionalVars[$varName]
    $value = [Environment]::GetEnvironmentVariable($varName)

    if (-not $value) {
        if ($Fix) {
            [Environment]::SetEnvironmentVariable($varName, $config.Default, 'Process')
            Write-Success "$varName - Set to default: $($config.Default)"
        }
        elseif ($Strict) {
            Write-Failure "$varName - $($config.Description) - NOT SET (default: $($config.Default))"
            $allValid = $false
        }
        else {
            Write-Info "$varName - Will use default: $($config.Default)"
        }
    }
    elseif ($config.Validator -and -not (& $config.Validator $value)) {
        Write-Failure "$varName - $($config.Description) - $($config.ErrorMessage): $value"
        $allValid = $false
    }
    else {
        Write-Success "$varName - $value"
    }
}

Write-Host "" 
Write-Host "Feature-Specific Configuration:" -ForegroundColor Yellow

$gdriveCredentials = [Environment]::GetEnvironmentVariable('GDRIVE_CREDENTIALS_PATH')
$gdriveToken = [Environment]::GetEnvironmentVariable('GDRIVE_TOKEN_PATH')
if ($gdriveCredentials -and $gdriveToken) {
    Write-Success "Google Drive - Credentials and token paths set"
}
elseif ($gdriveCredentials -or $gdriveToken) {
    Write-Warn "Google Drive - Partially configured (set both GDRIVE_CREDENTIALS_PATH and GDRIVE_TOKEN_PATH)"
}
else {
    Write-Info "Google Drive - Not configured (set GDRIVE_CREDENTIALS_PATH and GDRIVE_TOKEN_PATH to enable)"
}

$gdrtCreds = [Environment]::GetEnvironmentVariable('GDRT_CREDENTIALS_FILE')
$gdrtToken = [Environment]::GetEnvironmentVariable('GDRT_TOKEN_FILE')
if ($gdrtCreds -or $gdrtToken) {
    Write-Success "Google Drive Recovery - Using custom credential paths"
}
else {
    Write-Info "Google Drive Recovery - Using defaults (GDRT_CREDENTIALS_FILE/GDRT_TOKEN_FILE)"
}

if ([Environment]::GetEnvironmentVariable('CLOUDCONVERT_PROD')) {
    Write-Success "CloudConvert - Configured"
}
else {
    Write-Info "CloudConvert - Not configured (set CLOUDCONVERT_PROD to enable)"
}

Write-Host ""
Write-Host "=" * 60
if ($allValid) {
    Write-Success "Environment validation passed!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review configuration above"
    Write-Host "  2. Configure optional features as needed"
    Write-Host "  3. Run installation: ./scripts/Install-MyScripts.ps1" -ForegroundColor Cyan
    exit 0
}
else {
    Write-Failure "Environment validation failed!"
    Write-Host ""
    Write-Host "To fix:" -ForegroundColor Yellow
    Write-Host "  1. Copy .env.example to .env"
    Write-Host "  2. Edit .env with your values"
    Write-Host "  3. Load environment: . ./scripts/Load-Environment.ps1"
    Write-Host "  4. Run this script again"
    exit 1
}
