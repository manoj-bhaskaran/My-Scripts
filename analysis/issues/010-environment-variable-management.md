# Issue #010: Inconsistent Environment Variable Management

## Severity
**Low** - Functional but could be more consistent

## Category
Configuration / Developer Experience / Security

## Description
The repository uses environment variables for configuration (API keys, paths, secrets) but lacks:
- Centralized documentation of all required variables
- Validation of required variables at runtime
- Consistent naming conventions
- Clear setup instructions for different environments (dev, CI, production)

## Current State

### Environment Variables Used

**Python Scripts**:
- `GDRIVE_TOKEN_PATH` - Google Drive token location
- `GDRIVE_CREDENTIALS_PATH` - Google Drive credentials
- `CLOUDCONVERT_PROD` - CloudConvert API key
- Other undocumented variables likely exist

**PowerShell Scripts**:
- Variables loaded from `.env` file via `Load-Environment.ps1`
- No clear list of what's required vs. optional
- No validation of values

**CI/CD** (GitHub Secrets):
- `CODECOV_TOKEN`
- `SONAR_TOKEN`
- `GITHUB_TOKEN`
- Others possibly needed

### Current Documentation
- `.env.example` exists but may be incomplete
- `scripts/Load-Environment.ps1` loads variables but doesn't validate
- No centralized list of all environment variables
- No indication of which are required vs. optional

## Issues

### 1. Discovery Problem
New developers don't know:
- What environment variables are needed
- Which are required vs. optional
- What format values should be in
- Where to get values (API keys, tokens)

### 2. No Validation
Scripts fail at runtime with cryptic errors:
```python
# cloudconvert_utils.py:40
api_key = os.getenv("CLOUDCONVERT_PROD")
if not api_key:
    raise ValueError("CloudConvert API key not found")
# Only validated when script runs, not at setup time
```

### 3. Inconsistent Naming
No clear convention:
- `GDRIVE_TOKEN_PATH` (uppercase with underscores)
- `CLOUDCONVERT_PROD` (environment in variable name)
- Mixed patterns make it hard to remember variable names

### 4. Security Concerns
- No clear guidance on protecting sensitive values
- `.env` file must be gitignored (is it documented?)
- No mention of secret management tools (Vault, KeyPass, etc.)
- CI secrets not documented

### 5. Platform Differences
- PowerShell uses `.env` file
- Python reads directly from `os.getenv()`
- No unified approach
- Hard to share config between languages

## Impact

### Developer Onboarding
- **Confusion**: Don't know what to configure
- **Trial and Error**: Run script, get error, add variable, repeat
- **Time Wasted**: 30-60 minutes figuring out configuration
- **Frustration**: No clear "here's what you need" checklist

### Runtime Failures
- **Late Errors**: Only discover missing config when script runs
- **Cryptic Messages**: "API key not found" - which one?
- **Production Issues**: Missing config causes failures in scheduled tasks
- **No Fail-Fast**: Can't validate environment before running

### Security Risks
- **Accidental Commits**: .env file might be committed
- **Shared Secrets**: Unclear how to share secrets in teams
- **No Rotation**: No guidance on rotating API keys
- **Logging**: Secrets might be logged unintentionally

## Recommended Solutions

### Solution 1: Centralized Environment Documentation

**Create `docs/ENVIRONMENT.md`**:
```markdown
# Environment Variables

## Required Variables

### Google Drive Integration
- **GDRIVE_CREDENTIALS_PATH**
  - Description: Path to Google Drive OAuth2 credentials JSON
  - Format: Absolute file path
  - How to Get: https://console.cloud.google.com/apis/credentials
  - Example: `C:\Users\Username\Documents\Scripts\credentials.json`
  - Used By: google_drive_root_files_delete.py, gdrive_recover.py

- **GDRIVE_TOKEN_PATH**
  - Description: Path to Google Drive auth token (auto-generated)
  - Format: Absolute file path
  - Default: `Documents/Scripts/drive_token.json`
  - Used By: All Google Drive scripts

### CloudConvert Integration
- **CLOUDCONVERT_PROD**
  - Description: CloudConvert API key for file conversions
  - Format: String (alphanumeric token)
  - How to Get: https://cloudconvert.com/dashboard/api/v2/keys
  - Security: ⚠️ Keep secret, never commit
  - Used By: cloudconvert_utils.py

## Optional Variables

### HTTP Configuration
- **HTTP_TIMEOUT**
  - Description: Default HTTP request timeout in seconds
  - Format: Integer
  - Default: 30
  - Used By: All Python scripts with requests

## CI/CD Secrets (GitHub)

### Required for CI
- **CODECOV_TOKEN**: Codecov upload token
- **SONAR_TOKEN**: SonarCloud analysis token
- **GITHUB_TOKEN**: Automatic, provided by GitHub

## Setup Instructions

### Development Environment
1. Copy `.env.example` to `.env`
2. Fill in required variables (see above)
3. Run validation: `pwsh scripts/Verify-Environment.ps1`
4. Test: `pwsh scripts/Test-Configuration.ps1`

### CI/CD Environment
Configure GitHub Secrets at:
Settings → Secrets and variables → Actions

### Production/Scheduled Tasks
Use Windows environment variables or secure secret storage.
```

### Solution 2: Environment Validation Script

**Create `scripts/Verify-Environment.ps1`**:
```powershell
<#
.SYNOPSIS
    Validates environment configuration

.DESCRIPTION
    Checks all required environment variables are set and valid
    Run this before executing scripts to catch configuration issues early

.EXAMPLE
    ./scripts/Verify-Environment.ps1
    ./scripts/Verify-Environment.ps1 -Fix  # Prompts for missing values
#>

[CmdletBinding()]
param([switch]$Fix)

$requiredVars = @(
    @{
        Name = "GDRIVE_CREDENTIALS_PATH"
        Description = "Google Drive credentials JSON path"
        Validator = { Test-Path $_ }
        Optional = $false
    },
    @{
        Name = "CLOUDCONVERT_PROD"
        Description = "CloudConvert API key"
        Validator = { $_.Length -gt 20 }
        Optional = $false
    },
    @{
        Name = "HTTP_TIMEOUT"
        Description = "HTTP timeout in seconds"
        Validator = { [int]$_ -gt 0 }
        Optional = $true
        Default = "30"
    }
)

$issues = @()

foreach ($var in $requiredVars) {
    $value = [Environment]::GetEnvironmentVariable($var.Name)

    if (-not $value) {
        if ($var.Optional) {
            Write-Warning "Optional variable $($var.Name) not set (using default: $($var.Default))"
        } else {
            $issues += "Missing required variable: $($var.Name) - $($var.Description)"
        }
        continue
    }

    # Validate value
    if ($var.Validator -and -not (& $var.Validator $value)) {
        $issues += "Invalid value for $($var.Name): $value"
    }
}

if ($issues) {
    Write-Host "❌ Environment validation failed:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }

    if ($Fix) {
        Write-Host "`nWould you like to fix these issues? (Y/N): " -NoNewline
        $response = Read-Host
        if ($response -eq 'Y') {
            # Interactive fix mode
            foreach ($issue in $issues) {
                # Prompt user for values
            }
        }
    }

    exit 1
} else {
    Write-Host "✓ Environment validation passed" -ForegroundColor Green
    exit 0
}
```

**Add to CI/CD**:
```yaml
# .github/workflows/sonarcloud.yml
- name: Verify Environment Configuration
  shell: pwsh
  run: ./scripts/Verify-Environment.ps1
```

### Solution 3: Improved .env.example

**Comprehensive template**:
```bash
# .env.example - Copy to .env and fill in your values
# Keep .env in .gitignore - NEVER commit secrets!

# =============================================================================
# Google Drive Integration (Required for Google Drive scripts)
# =============================================================================
# Get credentials: https://console.cloud.google.com/apis/credentials
GDRIVE_CREDENTIALS_PATH=C:/Users/YOUR_USERNAME/Documents/Scripts/credentials.json
# Token is auto-generated on first run
GDRIVE_TOKEN_PATH=C:/Users/YOUR_USERNAME/Documents/Scripts/drive_token.json

# =============================================================================
# CloudConvert Integration (Required for file conversion scripts)
# =============================================================================
# Get API key: https://cloudconvert.com/dashboard/api/v2/keys
# ⚠️ KEEP SECRET - Never commit this value
CLOUDCONVERT_PROD=your_cloudconvert_api_key_here

# =============================================================================
# HTTP Configuration (Optional)
# =============================================================================
# HTTP_TIMEOUT=30
# HTTP_CONNECT_TIMEOUT=5

# =============================================================================
# Logging Configuration (Optional)
# =============================================================================
# LOG_LEVEL=INFO
# LOG_DIR=./logs

# =============================================================================
# PostgreSQL Configuration (Optional, for backup scripts)
# =============================================================================
# PGHOST=localhost
# PGPORT=5432
# PGUSER=postgres
# PGPASSWORD=your_password_here
```

### Solution 4: Python Environment Validation

**Create `src/python/modules/utils/environment.py`**:
```python
"""Environment variable validation and management."""

import os
from pathlib import Path
from typing import Dict, Callable, Optional, Any

class EnvironmentConfig:
    """Validates and provides access to environment variables."""

    REQUIRED_VARS = {
        "CLOUDCONVERT_PROD": {
            "description": "CloudConvert API key",
            "validator": lambda v: len(v) > 20,
            "optional": False
        },
        "GDRIVE_CREDENTIALS_PATH": {
            "description": "Google Drive credentials JSON path",
            "validator": lambda v: Path(v).exists(),
            "optional": False,
            "required_for": ["google_drive"]
        }
    }

    @classmethod
    def validate(cls, strict: bool = True) -> Dict[str, Any]:
        """
        Validate all environment variables.

        Args:
            strict: If True, raise on missing required vars. If False, warn only.

        Returns:
            Dict of validation results

        Raises:
            EnvironmentError: If strict=True and validation fails
        """
        issues = []

        for var_name, config in cls.REQUIRED_VARS.items():
            value = os.getenv(var_name)

            if not value:
                if config["optional"]:
                    continue
                else:
                    issues.append(f"Missing required: {var_name} - {config['description']}")
                    continue

            # Validate value
            if config.get("validator") and not config["validator"](value):
                issues.append(f"Invalid value for {var_name}")

        if issues:
            message = "Environment validation failed:\n" + "\n".join(issues)
            if strict:
                raise EnvironmentError(message)
            else:
                print(f"Warning: {message}")

        return {"valid": len(issues) == 0, "issues": issues}

    @classmethod
    def get_required(cls, var_name: str) -> str:
        """Get required environment variable or raise."""
        value = os.getenv(var_name)
        if not value:
            raise EnvironmentError(
                f"Required environment variable not set: {var_name}\n"
                f"See docs/ENVIRONMENT.md for setup instructions"
            )
        return value

# Validate on import (fail fast)
# EnvironmentConfig.validate(strict=False)  # Warning only for now
```

**Use in scripts**:
```python
from modules.utils.environment import EnvironmentConfig

# Validate early
EnvironmentConfig.validate()

# Get variables safely
api_key = EnvironmentConfig.get_required("CLOUDCONVERT_PROD")
```

## Implementation Steps

### Week 1: Documentation
- [ ] Create docs/ENVIRONMENT.md with all variables
- [ ] Update .env.example with comprehensive comments
- [ ] Add environment setup to INSTALLATION.md
- [ ] Document CI/CD secrets

### Week 2: Validation Scripts
- [ ] Create Verify-Environment.ps1
- [ ] Create Python environment.py module
- [ ] Add validation to CI/CD
- [ ] Add to pre-commit hook (optional)

### Week 3: Refactor Scripts
- [ ] Update scripts to use validation
- [ ] Add fail-fast checks at script entry
- [ ] Improve error messages
- [ ] Add links to ENVIRONMENT.md in errors

### Week 4: Testing and Documentation
- [ ] Test validation with missing variables
- [ ] Test validation with invalid values
- [ ] Update all script READMEs
- [ ] Create video walkthrough (optional)

## Acceptance Criteria
- [ ] docs/ENVIRONMENT.md documents all variables
- [ ] Comprehensive .env.example
- [ ] Verify-Environment.ps1 validates all variables
- [ ] Python environment.py validates all variables
- [ ] CI/CD runs validation
- [ ] All scripts use validation
- [ ] Error messages reference docs/ENVIRONMENT.md

## Benefits
- **Faster Onboarding**: Clear list of what's needed
- **Fewer Errors**: Catch misconfigurations early
- **Better Security**: Clear guidance on protecting secrets
- **Improved UX**: Helpful error messages
- **Documentation**: Single source of truth

## Effort Estimate
- **Documentation**: 8-12 hours
- **Validation Scripts**: 12-16 hours
- **Integration**: 8-12 hours
- **Testing**: 4-8 hours

**Total**: ~32-48 hours (4-6 days)

## Priority
**Low-Medium** - Would significantly improve developer experience but not blocking current functionality.

## Related Issues
- Issue #009: Configuration management
- Documentation improvements
- Security best practices

## Notes
- Good pairing with module deployment improvements (Issue #009)
- Could use dotenv library for Python
- Consider secret management tools for teams
- Validation helps with Issue #003 (testing) - tests can validate environments
