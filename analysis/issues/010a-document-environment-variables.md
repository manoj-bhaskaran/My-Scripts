# Issue #010a: Create Comprehensive Environment Variable Documentation

**Parent Issue**: [#010: Environment Variable Management](./010-environment-variable-management.md)
**Phase**: Phase 1 - Documentation
**Effort**: 4-6 hours

## Description
Create centralized documentation listing all environment variables, their purposes, formats, and how to obtain values. This is the foundation for all other environment improvements.

## Implementation

### Create docs/ENVIRONMENT.md
```markdown
# Environment Variables Reference

Complete reference of all environment variables used in My-Scripts.

## Quick Start

1. Copy `.env.example` to `.env`
2. Fill in required variables (marked with ⚠️)
3. Run validation: `pwsh ./scripts/Verify-Environment.ps1`
4. Test scripts

---

## Required Variables

### Google Drive Integration

#### GDRIVE_CREDENTIALS_PATH
- **Required**: ⚠️ Yes (for Google Drive scripts)
- **Description**: Path to Google Drive OAuth2 credentials JSON file
- **Format**: Absolute file path
- **How to Get**:
  1. Go to https://console.cloud.google.com/apis/credentials
  2. Create project or select existing
  3. Enable Google Drive API
  4. Create OAuth 2.0 credentials
  5. Download JSON file
- **Example**: `C:\Users\Username\Documents\Scripts\credentials.json`
- **Used By**:
  - `src/python/cloud/google_drive_root_files_delete.py`
  - `src/python/cloud/gdrive_recover.py`
  - `src/python/cloud/drive_space_monitor.py`

#### GDRIVE_TOKEN_PATH
- **Required**: No (auto-generated)
- **Description**: Path where Google Drive auth token will be stored
- **Format**: Absolute file path
- **Default**: `{HOME}/Documents/Scripts/drive_token.json`
- **Note**: Created automatically on first authentication
- **Used By**: All Google Drive scripts

---

### CloudConvert Integration

#### CLOUDCONVERT_PROD
- **Required**: ⚠️ Yes (for file conversion scripts)
- **Description**: CloudConvert API key for file conversions
- **Format**: String (alphanumeric token, ~40 characters)
- **How to Get**:
  1. Sign up at https://cloudconvert.com
  2. Go to https://cloudconvert.com/dashboard/api/v2/keys
  3. Create new API key
  4. Copy the key
- **Security**: ⚠️ **KEEP SECRET** - Never commit to git
- **Example**: `eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...`
- **Used By**:
  - `src/python/cloud/cloudconvert_utils.py`
  - `src/powershell/cloud/Invoke-CloudConvert.ps1`

---

## Optional Variables

### HTTP Configuration

#### HTTP_TIMEOUT
- **Required**: No
- **Description**: Default HTTP request timeout in seconds
- **Format**: Integer
- **Default**: `30`
- **Example**: `60`
- **Used By**: All Python scripts making HTTP requests

#### HTTP_CONNECT_TIMEOUT
- **Required**: No
- **Description**: TCP connection timeout in seconds
- **Format**: Integer
- **Default**: `5`
- **Example**: `10`
- **Used By**: All Python scripts making HTTP requests

---

### Logging Configuration

#### LOG_LEVEL
- **Required**: No
- **Description**: Minimum logging level
- **Format**: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
- **Default**: `INFO`
- **Example**: `DEBUG`
- **Used By**: All scripts using logging framework

#### LOG_DIR
- **Required**: No
- **Description**: Directory for log files
- **Format**: Absolute path
- **Default**: `./logs` (current directory)
- **Example**: `C:\Logs\MyScripts`
- **Used By**: All scripts using logging framework

---

### PostgreSQL Configuration

#### PGHOST
- **Required**: No (for PostgreSQL scripts)
- **Description**: PostgreSQL server hostname
- **Format**: Hostname or IP address
- **Default**: `localhost`
- **Example**: `192.168.1.100`
- **Used By**: PostgreSQL backup scripts

#### PGPORT
- **Required**: No
- **Description**: PostgreSQL server port
- **Format**: Integer (1-65535)
- **Default**: `5432`
- **Example**: `5433`

#### PGUSER
- **Required**: No
- **Description**: PostgreSQL username
- **Format**: String
- **Default**: `postgres`
- **Example**: `myuser`

#### PGPASSWORD
- **Required**: No (for automated backups)
- **Description**: PostgreSQL password
- **Format**: String
- **Security**: ⚠️ **KEEP SECRET**
- **Note**: Consider using .pgpass file instead
- **Used By**: Backup scripts

---

## CI/CD Secrets (GitHub)

These are configured in GitHub repository settings, not local .env file.

### CODECOV_TOKEN
- **Required**: Yes (for CI)
- **Description**: Codecov upload token for coverage reports
- **Where**: GitHub → Settings → Secrets → Actions
- **How to Get**: https://codecov.io → Repository Settings → Copy token

### SONAR_TOKEN
- **Required**: Yes (for CI)
- **Description**: SonarCloud analysis token
- **Where**: GitHub → Settings → Secrets → Actions
- **How to Get**: https://sonarcloud.io → My Account → Security → Generate token

### GITHUB_TOKEN
- **Required**: Automatic
- **Description**: GitHub Actions authentication token
- **Note**: Provided automatically by GitHub Actions
- **Used By**: All workflows

---

## Setup Instructions

### Development Environment

1. **Copy example file**:
   \`\`\`bash
   cp .env.example .env
   \`\`\`

2. **Edit .env file** with your values:
   \`\`\`bash
   # Windows
   notepad .env

   # Linux/Mac
   nano .env
   \`\`\`

3. **Validate configuration**:
   \`\`\`powershell
   pwsh ./scripts/Verify-Environment.ps1
   \`\`\`

4. **Test with a script**:
   \`\`\`powershell
   python src/python/data/csv_to_gpx.py --help
   \`\`\`

### CI/CD Environment

Configure secrets in GitHub repository:
Settings → Secrets and variables → Actions → New repository secret

### Production/Scheduled Tasks

For Windows Task Scheduler:
1. Use system environment variables (not .env file)
2. Set variables in Task Scheduler action settings
3. Or use PowerShell's `Load-Environment.ps1`

---

## Security Best Practices

### Never Commit Secrets
\`\`\`bash
# Verify .env is in .gitignore
grep ".env" .gitignore

# Should show: .env
\`\`\`

### Use Different Keys Per Environment
- Development: Use sandbox/test API keys
- Production: Use production API keys
- Never share production keys

### Rotate Keys Regularly
- Rotate API keys every 90 days
- Rotate after team member departure
- Rotate if key potentially exposed

### Use Secret Management Tools
Consider:
- Windows Credential Manager
- macOS Keychain
- Linux Secret Service
- HashiCorp Vault (for teams)

---

## Troubleshooting

### "Environment variable not found"
1. Check .env file exists: `test -f .env`
2. Check variable is set: `echo $VARIABLE_NAME`
3. Check spelling matches exactly
4. Run: `pwsh ./scripts/Verify-Environment.ps1`

### "Invalid credentials"
1. Verify API key is correct
2. Check for extra spaces/newlines
3. Ensure key hasn't expired
4. Test key directly via API

### Scripts can't find .env file
1. Run scripts from repository root
2. Or set absolute paths in variables
3. Use `Load-Environment.ps1` in scripts

---

## Related Documentation

- [Installation Guide](../INSTALLATION.md)
- [Configuration Guide](../config/CONFIG_GUIDE.md)
- [Contributing Guidelines](../CONTRIBUTING.md)
```

## .gitignore Entry
```gitignore
# Environment files
.env
.env.local
.env.*.local
psmodule.local.toml
config/local-deployment-config.json
config/secrets/
```

## Acceptance Criteria
- [ ] docs/ENVIRONMENT.md created with all variables
- [ ] Each variable has: description, format, how to get, used by
- [ ] Required vs optional clearly marked
- [ ] Security warnings for secrets
- [ ] Setup instructions for dev/CI/production
- [ ] Troubleshooting section
- [ ] .gitignore verified

## Benefits
- Single source of truth
- Clear onboarding path
- Security best practices documented
- Troubleshooting guide

## Effort
4-6 hours

## Related
- Issue #010b (create validation script)
- Issue #010c (improve .env.example)
