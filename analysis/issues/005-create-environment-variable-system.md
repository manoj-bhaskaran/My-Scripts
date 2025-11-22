# ISSUE-005: Create Comprehensive Environment Variable System

**Priority:** 🟠 HIGH
**Category:** Configuration / Documentation / Portability
**Estimated Effort:** 6 hours
**Skills Required:** Bash, PowerShell, Documentation, Python

---

## Problem Statement

Scripts use environment variables but there's no central documentation or validation system. Users don't know what variables to set, leading to cryptic runtime errors and difficult troubleshooting.

### Current State

**Environment Variables Currently Used (undocumented):**
- `CLOUDCONVERT_PROD` (cloudconvert_utils.py)
- `GDRT_CREDENTIALS_FILE` (gdrive_recover.py)
- `GDRT_STRICT_POLICY` (gdrive_recover.py)
- `MY_SCRIPTS_ROOT` (implied in Task Scheduler)
- `GDRIVE_TOKEN_PATH` (should be used, currently hardcoded)
- `GDRIVE_CREDENTIALS_PATH` (should be used, currently hardcoded)

**Problems:**
- ❌ No `.env.example` file
- ❌ No central documentation
- ❌ No validation script
- ❌ Cryptic errors when variables missing
- ❌ No guidance on default values

### Impact

- 💥 **Setup Failures:** Scripts fail with unclear errors
- ❓ **Confusion:** Users don't know what to configure
- 🐛 **Hard to Debug:** Missing env vars cause cryptic errors
- 📚 **Poor Documentation:** No single source of truth
- 😤 **Frustrating Experience:** Trial and error setup

---

## Acceptance Criteria

- [ ] Create comprehensive `.env.example` file with all environment variables
- [ ] Document each variable with description, type, default, required status
- [ ] Create validation script (`scripts/Verify-Environment.ps1`)
- [ ] Create validation script (`scripts/verify-environment.sh`)
- [ ] Update INSTALLATION.md with environment setup section
- [ ] Add environment validation to CI pipeline
- [ ] Create environment variable reference documentation
- [ ] Test setup process on fresh system
- [ ] All scripts updated to use environment variables (links to ISSUE-001, ISSUE-008)

---

## Implementation Plan

### Step 1: Create .env.example (2 hours)

```bash
# .env.example

# ==========================================
# My-Scripts Environment Configuration
# ==========================================
# Copy this file to .env and fill in your values:
#   cp .env.example .env
#
# Then load it before running scripts:
#   PowerShell: . ./scripts/Load-Environment.ps1
#   Bash:       source scripts/load-environment.sh
# ==========================================

# ==========================================
# Core Paths
# ==========================================

# MY_SCRIPTS_ROOT - Root directory for script execution
# Type: string (path)
# Required: Yes
# Default: None
# Description: Main working directory where scripts are deployed and executed.
#              Task Scheduler jobs use this path to find scripts.
# Example: C:\Users\YourName\Documents\Scripts
MY_SCRIPTS_ROOT=

# MY_SCRIPTS_REPO - Repository directory (for development)
# Type: string (path)
# Required: No (only for development)
# Default: Current directory
# Description: Git repository location. Only needed if developing/contributing.
# Example: C:\Users\YourName\Projects\My-Scripts
MY_SCRIPTS_REPO=

# ==========================================
# CloudConvert API
# ==========================================

# CLOUDCONVERT_PROD - CloudConvert API key
# Type: string (API key)
# Required: Yes (if using cloud conversion features)
# Default: None
# Description: Production API key for CloudConvert service.
#              Get your API key from: https://cloudconvert.com/dashboard/api/v2/keys
# Example: your_api_key_here
CLOUDCONVERT_PROD=

# ==========================================
# Google Drive Integration
# ==========================================

# GDRIVE_TOKEN_PATH - Google Drive OAuth2 token file
# Type: string (file path)
# Required: Yes (if using Google Drive features)
# Default: ~/Documents/Scripts/drive_token.json
# Description: Path to OAuth2 token file. Created automatically on first auth.
# Example: /home/user/credentials/drive_token.json
GDRIVE_TOKEN_PATH=

# GDRIVE_CREDENTIALS_PATH - Google Drive API credentials
# Type: string (file path)
# Required: Yes (if using Google Drive features)
# Default: ~/Documents/Scripts/credentials.json
# Description: Path to Google Drive API credentials from Google Cloud Console.
#              Get credentials from: https://console.cloud.google.com/apis/credentials
# Example: /home/user/credentials/google-drive-credentials.json
GDRIVE_CREDENTIALS_PATH=

# ==========================================
# Google Drive Recovery Tool
# ==========================================

# GDRT_CREDENTIALS_FILE - Credentials for recovery tool
# Type: string (file path)
# Required: Yes (if using gdrive_recover.py)
# Default: Same as GDRIVE_CREDENTIALS_PATH
# Description: Credentials file for Google Drive recovery operations
GDRT_CREDENTIALS_FILE=

# GDRT_STRICT_POLICY - Strict policy enforcement
# Type: integer (0 or 1)
# Required: No
# Default: 0
# Description: Enable strict policy checking for recovery operations
#              0 = disabled, 1 = enabled
GDRT_STRICT_POLICY=0

# ==========================================
# Database Configuration
# ==========================================

# PostgreSQL connection settings
# Note: If not set, scripts will use PostgreSQL defaults

# PGHOST - PostgreSQL server hostname
# Type: string (hostname or IP)
# Required: No
# Default: localhost
# Example: localhost
PGHOST=localhost

# PGPORT - PostgreSQL server port
# Type: integer (port number)
# Required: No
# Default: 5432
PGPORT=5432

# PGUSER - PostgreSQL username
# Type: string (username)
# Required: No
# Default: postgres
# Example: backup_user
PGUSER=postgres

# PGDATABASE - Default database
# Type: string (database name)
# Required: No
# Default: postgres
PGDATABASE=postgres

# BACKUP_RETENTION_DAYS - How long to keep backups
# Type: integer (days)
# Required: No
# Default: 30
# Description: Number of days to retain database backups before deletion
BACKUP_RETENTION_DAYS=30

# ==========================================
# Logging Configuration
# ==========================================

# LOG_LEVEL - Logging verbosity level
# Type: string (DEBUG, INFO, WARNING, ERROR, CRITICAL)
# Required: No
# Default: INFO
# Description: Controls logging verbosity. Use DEBUG for troubleshooting.
LOG_LEVEL=INFO

# LOG_DIR - Custom log directory
# Type: string (directory path)
# Required: No
# Default: ./logs
# Description: Override default log directory location
# Example: C:\Logs\MyScripts
LOG_DIR=

# LOG_RETENTION_DAYS - Log file retention period
# Type: integer (days)
# Required: No
# Default: 90
# Description: Number of days to retain log files before automatic cleanup
LOG_RETENTION_DAYS=90

# ==========================================
# Email Notifications (Optional)
# ==========================================

# SMTP_SERVER - SMTP server for email notifications
# Type: string (hostname)
# Required: No (only if using email notifications)
# Default: None
SMTP_SERVER=

# SMTP_PORT - SMTP server port
# Type: integer (port number)
# Required: No
# Default: 587
SMTP_PORT=587

# SMTP_USERNAME - SMTP authentication username
# Type: string (username)
# Required: No
SMTP_USERNAME=

# SMTP_PASSWORD - SMTP authentication password
# Type: string (password)
# Required: No
# Security: Store securely, consider using encrypted credentials
SMTP_PASSWORD=

# NOTIFICATION_EMAIL - Email address for notifications
# Type: string (email address)
# Required: No
NOTIFICATION_EMAIL=

# ==========================================
# Advanced Settings
# ==========================================

# PARALLEL_JOBS - Number of parallel jobs for processing
# Type: integer (1-16)
# Required: No
# Default: 4
# Description: Number of concurrent jobs for parallel processing
PARALLEL_JOBS=4

# ENABLE_TELEMETRY - Enable anonymous usage telemetry
# Type: boolean (true/false)
# Required: No
# Default: false
# Description: Send anonymous usage statistics to help improve scripts
ENABLE_TELEMETRY=false
```

### Step 2: Create PowerShell Validation Script (1.5 hours)

```powershell
# scripts/Verify-Environment.ps1

<#
.SYNOPSIS
    Validates environment variable configuration

.DESCRIPTION
    Checks that all required environment variables are set and validates
    their values. Provides helpful error messages for missing or invalid configuration.

.PARAMETER Fix
    Automatically set missing optional variables to defaults

.PARAMETER Strict
    Fail if any optional variables are missing

.EXAMPLE
    .\Verify-Environment.ps1
    Checks environment variables and reports status

.EXAMPLE
    .\Verify-Environment.ps1 -Fix
    Checks and fixes missing optional variables
#>

[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$Strict
)

# Color output helpers
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Failure { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }

Write-Info "Verifying Environment Configuration..."
Write-Host ""

$allValid = $true
$warnings = @()

# Define required variables
$requiredVars = @{
    'MY_SCRIPTS_ROOT' = @{
        Description = 'Script root directory'
        Validator = { param($v) Test-Path $v }
        ErrorMessage = 'Path does not exist'
    }
}

# Define optional variables with defaults
$optionalVars = @{
    'LOG_LEVEL' = @{
        Description = 'Logging level'
        Default = 'INFO'
        Validator = { param($v) $v -in @('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL') }
        ErrorMessage = 'Must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL'
    }
    'LOG_DIR' = @{
        Description = 'Log directory'
        Default = '.\logs'
        Validator = { $true }  # Will be created if needed
    }
    'BACKUP_RETENTION_DAYS' = @{
        Description = 'Backup retention days'
        Default = '30'
        Validator = { param($v) [int]$v -gt 0 }
        ErrorMessage = 'Must be positive integer'
    }
    'PGHOST' = @{
        Description = 'PostgreSQL host'
        Default = 'localhost'
    }
    'PGPORT' = @{
        Description = 'PostgreSQL port'
        Default = '5432'
        Validator = { param($v) [int]$v -ge 1 -and [int]$v -le 65535 }
        ErrorMessage = 'Must be valid port number (1-65535)'
    }
}

# Check required variables
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
            Write-Failure "$varName - $($config.Description) - NOT SET (would default to: $($config.Default))"
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

# Feature-specific checks
Write-Host ""
Write-Host "Feature-Specific Configuration:" -ForegroundColor Yellow

# Google Drive
$gdriveVars = @('GDRIVE_CREDENTIALS_PATH', 'GDRIVE_TOKEN_PATH')
$gdriveConfigured = $true
foreach ($var in $gdriveVars) {
    $value = [Environment]::GetEnvironmentVariable($var)
    if (-not $value) {
        $gdriveConfigured = $false
        break
    }
}

if ($gdriveConfigured) {
    Write-Success "Google Drive - Configured"
}
else {
    Write-Info "Google Drive - Not configured (set $($gdriveVars -join ', ') to enable)"
}

# CloudConvert
$cloudConvertKey = [Environment]::GetEnvironmentVariable('CLOUDCONVERT_PROD')
if ($cloudConvertKey) {
    Write-Success "CloudConvert - Configured"
}
else {
    Write-Info "CloudConvert - Not configured (set CLOUDCONVERT_PROD to enable)"
}

# Summary
Write-Host ""
Write-Host "=" * 60
if ($allValid) {
    Write-Success "Environment validation passed!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review configuration above"
    Write-Host "  2. Configure optional features as needed"
    Write-Host "  3. Run installation: .\scripts\Install-MyScripts.ps1"
    exit 0
}
else {
    Write-Failure "Environment validation failed!"
    Write-Host ""
    Write-Host "To fix:" -ForegroundColor Yellow
    Write-Host "  1. Copy .env.example to .env"
    Write-Host "  2. Edit .env with your values"
    Write-Host "  3. Load environment: . .\scripts\Load-Environment.ps1"
    Write-Host "  4. Run this script again"
    exit 1
}
```

### Step 3: Create Bash Validation Script (1 hour)

```bash
# scripts/verify-environment.sh
#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
success() { echo -e "${GREEN}✓${NC} $1"; }
failure() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }

echo -e "${CYAN}Verifying Environment Configuration...${NC}\n"

all_valid=true

# Check required variables
echo -e "${YELLOW}Required Variables:${NC}"

check_required() {
    local var_name=$1
    local description=$2
    local value=${!var_name}

    if [ -z "$value" ]; then
        failure "$var_name - $description - NOT SET"
        all_valid=false
    else
        success "$var_name - $description - $value"
    fi
}

check_required "MY_SCRIPTS_ROOT" "Script root directory"

# Check optional variables
echo -e "\n${YELLOW}Optional Variables:${NC}"

check_optional() {
    local var_name=$1
    local description=$2
    local default=$3
    local value=${!var_name}

    if [ -z "$value" ]; then
        info "$var_name - Will use default: $default"
    else
        success "$var_name - $value"
    fi
}

check_optional "LOG_LEVEL" "Logging level" "INFO"
check_optional "LOG_DIR" "Log directory" "./logs"
check_optional "BACKUP_RETENTION_DAYS" "Backup retention" "30"
check_optional "PGHOST" "PostgreSQL host" "localhost"
check_optional "PGPORT" "PostgreSQL port" "5432"

# Feature checks
echo -e "\n${YELLOW}Feature-Specific Configuration:${NC}"

if [ -n "$GDRIVE_CREDENTIALS_PATH" ] && [ -n "$GDRIVE_TOKEN_PATH" ]; then
    success "Google Drive - Configured"
else
    info "Google Drive - Not configured"
fi

if [ -n "$CLOUDCONVERT_PROD" ]; then
    success "CloudConvert - Configured"
else
    info "CloudConvert - Not configured"
fi

# Summary
echo ""
echo "============================================================"
if $all_valid; then
    success "Environment validation passed!"
    echo -e "\nNext steps:"
    echo "  1. Review configuration above"
    echo "  2. Configure optional features as needed"
    echo "  3. Run installation script"
    exit 0
else
    failure "Environment validation failed!"
    echo -e "\n${YELLOW}To fix:${NC}"
    echo "  1. Copy .env.example to .env"
    echo "  2. Edit .env with your values"
    echo "  3. Load environment: source scripts/load-environment.sh"
    echo "  4. Run this script again"
    exit 1
fi
```

### Step 4: Create Environment Loader Scripts (30 minutes)

```powershell
# scripts/Load-Environment.ps1
<#
.SYNOPSIS
    Loads environment variables from .env file
#>

$envFile = Join-Path $PSScriptRoot ".." ".env"

if (-not (Test-Path $envFile)) {
    Write-Warning ".env file not found at: $envFile"
    Write-Host "Copy .env.example to .env and configure your values"
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

        # Remove quotes if present
        $value = $value -replace '^["'']|["'']$', ''

        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        Write-Verbose "Set $name"
    }
}

Write-Host "Environment loaded from $envFile" -ForegroundColor Green
```

```bash
# scripts/load-environment.sh
#!/bin/bash

ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "⚠ .env file not found at: $ENV_FILE"
    echo "Copy .env.example to .env and configure your values"
    return 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a

echo "✓ Environment loaded from $ENV_FILE"
```

### Step 5: Update Documentation (1 hour)

Add to `INSTALLATION.md`:

```markdown
## Environment Configuration

### Quick Setup

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your values:**
   - Required: `MY_SCRIPTS_ROOT` - Main script directory
   - Optional: Configure features you'll use (Google Drive, CloudConvert, etc.)

3. **Load environment variables:**

   **PowerShell:**
   ```powershell
   . .\scripts\Load-Environment.ps1
   ```

   **Bash:**
   ```bash
   source scripts/load-environment.sh
   ```

4. **Verify configuration:**

   **PowerShell:**
   ```powershell
   .\scripts\Verify-Environment.ps1
   ```

   **Bash:**
   ```bash
   ./scripts/verify-environment.sh
   ```

### Environment Variable Reference

See [`.env.example`](.env.example) for complete documentation of all available environment variables.

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MY_SCRIPTS_ROOT` | Main script directory | `C:\Users\Name\Documents\Scripts` |

#### Feature-Specific Variables

**Google Drive Integration:**
- `GDRIVE_CREDENTIALS_PATH` - API credentials file
- `GDRIVE_TOKEN_PATH` - OAuth token file

**CloudConvert:**
- `CLOUDCONVERT_PROD` - API key

**Database Backups:**
- `PGHOST`, `PGPORT`, `PGUSER` - PostgreSQL connection
- `BACKUP_RETENTION_DAYS` - Backup retention policy

See [Environment Variables Guide](docs/guides/environment-variables.md) for detailed information.
```

### Step 6: Create Reference Documentation (1 hour)

Create `docs/guides/environment-variables.md` with comprehensive variable reference.

---

## Testing Strategy

### Validation Testing
- Run verify scripts with no environment → should fail
- Run verify scripts with partial environment → should warn
- Run verify scripts with complete environment → should pass
- Test Fix parameter sets defaults correctly

### Documentation Testing
- Follow setup guide on fresh system
- Verify all variables documented
- Check examples are correct
- Test on Windows and Linux

### Integration Testing
- Verify scripts work with environment variables
- Test fallback to defaults works
- Verify validation catches invalid values

---

## Related Issues

- ISSUE-001: Fix Hardcoded Credentials Paths
- ISSUE-008: Fix Hardcoded Paths in Scripts
- ISSUE-009: Fix Hardcoded Paths in Documentation

---

## References

- dotenv documentation: https://github.com/motdotla/dotenv
- Environment Variables Best Practices: https://12factor.net/config
- PowerShell Environment Variables: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables

---

## Success Metrics

- [ ] `.env.example` created with all variables documented
- [ ] Validation scripts work on Windows and Linux
- [ ] Documentation updated with setup guide
- [ ] All variables have description, type, default, required status
- [ ] Validation catches missing required variables
- [ ] Validation provides helpful error messages
- [ ] Fresh system setup successful following documentation

---

**Estimated Time Breakdown:**
- Create .env.example: 2 hours
- PowerShell validation script: 1.5 hours
- Bash validation script: 1 hour
- Environment loader scripts: 0.5 hours
- Update INSTALLATION.md: 0.5 hours
- Create reference documentation: 0.5 hours
- **Total: 6 hours**
