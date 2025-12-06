# Environment Variables Reference

Complete reference of all environment variables used in My-Scripts.

## Quick Start

1. Copy `.env.example` to `.env`
2. Fill in required variables (marked with ⚠️)
3. Run validation: `pwsh ./scripts/Verify-Environment.ps1`
4. Test scripts

---

## Required Variables

### Core Path Configuration

#### MY_SCRIPTS_ROOT
- **Required**: ⚠️ Yes
- **Description**: Root directory where scripts are deployed and executed
- **Format**: Absolute directory path
- **How to Get**:
  1. Decide where you want scripts to run (e.g., `C:\Scripts` or `~/Documents/Scripts`)
  2. Create the directory if it doesn't exist
  3. Set this variable to that path
- **Example**: `C:\Users\Username\Documents\Scripts` (Windows) or `/home/username/Documents/Scripts` (Linux)
- **Used By**:
  - `scripts/Verify-Environment.ps1`
  - `scripts/Initialize-Configuration.ps1`
  - Windows Task Scheduler jobs (for scheduled scripts)
- **Note**: This is the most critical variable - most scripts require this to run properly

---

### Google Drive Integration

#### GDRIVE_CREDENTIALS_PATH
- **Required**: ⚠️ Yes (for Google Drive scripts)
- **Description**: Path to Google Drive OAuth2 credentials JSON file
- **Format**: Absolute file path
- **How to Get**:
  1. Go to https://console.cloud.google.com/apis/credentials
  2. Create a new project or select an existing one
  3. Enable Google Drive API for your project
  4. Create OAuth 2.0 Client ID credentials
     - Application type: Desktop app
     - Name: My-Scripts (or your choice)
  5. Download the JSON credentials file
  6. Save it to a secure location
  7. Set this variable to the full path
- **Example**: `C:\Users\Username\Documents\Scripts\credentials.json` or `/home/username/credentials/google-drive-credentials.json`
- **Security**: ⚠️ **KEEP SECRET** - Never commit to git
- **Used By**:
  - `src/python/modules/auth/google_drive_auth.py`
  - `src/python/cloud/google_drive_root_files_delete.py`
  - `src/python/cloud/gdrive_recover.py`
  - `src/python/cloud/drive_space_monitor.py`

#### GDRIVE_TOKEN_PATH
- **Required**: No (auto-generated)
- **Description**: Path where Google Drive OAuth token will be stored
- **Format**: Absolute file path
- **Default**: `~/Documents/Scripts/drive_token.json`
- **Note**: Created automatically on first authentication. This file caches your authentication so you don't need to re-authenticate every time.
- **Example**: `C:\Users\Username\Documents\Scripts\drive_token.json` or `/home/username/Documents/Scripts/drive_token.json`
- **Used By**: All Google Drive scripts

---

### Google Drive Recovery Tool

These variables are specific to the Google Drive recovery utility (`gdrive_recover.py`) and allow separate credentials from the main Google Drive integration.

#### GDRT_CREDENTIALS_FILE
- **Required**: No (uses GDRIVE_CREDENTIALS_PATH if not set)
- **Description**: Separate credentials file for Google Drive recovery operations
- **Format**: Absolute file path
- **Default**: Falls back to `GDRIVE_CREDENTIALS_PATH` or `./credentials.json`
- **Example**: `C:\Users\Username\Documents\Scripts\gdrive_recovery_credentials.json`
- **Used By**: `src/python/cloud/gdrive_recover.py` (line 188)

#### GDRT_TOKEN_FILE
- **Required**: No (uses GDRIVE_TOKEN_PATH if not set)
- **Description**: OAuth token cache for recovery tool
- **Format**: Absolute file path
- **Default**: Falls back to `GDRIVE_TOKEN_PATH` or `./token.json`
- **Example**: `C:\Users\Username\Documents\Scripts\gdrive_recovery_token.json`
- **Used By**: `src/python/cloud/gdrive_recover.py` (line 189)

#### GDRT_STRICT_POLICY
- **Required**: No
- **Description**: Enable strict policy checking for recovery operations
- **Format**: Integer (0 or 1)
- **Default**: `0` (disabled)
- **Values**:
  - `0` = Disabled (permissive mode)
  - `1` = Enabled (strict mode - enforces stricter validation)
- **Example**: `1`
- **Used By**: `src/python/cloud/gdrive_recover.py` (line 2898)

---

### CloudConvert Integration

#### CLOUDCONVERT_PROD
- **Required**: ⚠️ Yes (for file conversion scripts)
- **Description**: CloudConvert API key for file conversions
- **Format**: String (alphanumeric token, approximately 40 characters)
- **How to Get**:
  1. Sign up at https://cloudconvert.com
  2. Navigate to https://cloudconvert.com/dashboard/api/v2/keys
  3. Click "Create New API Key"
  4. Give it a descriptive name (e.g., "My-Scripts")
  5. Copy the generated API key
  6. Set this variable to that key
- **Security**: ⚠️ **KEEP SECRET** - Never commit to git
- **Example**: `eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...` (JWT token)
- **Used By**:
  - `src/python/cloud/cloudconvert_utils.py` (line 47)
  - `src/powershell/cloud/Invoke-CloudConvert.ps1`
- **Note**: CloudConvert has a free tier with limited conversions per month. Check your plan limits.

---

## Optional Variables

### Development Configuration

#### MY_SCRIPTS_REPO
- **Required**: No (only for development)
- **Description**: Git repository location for development work
- **Format**: Absolute directory path
- **Default**: Current directory
- **Example**: `C:\Users\Username\Projects\My-Scripts` or `/home/username/Projects/My-Scripts`
- **Note**: Only needed if you're developing/contributing to My-Scripts. Allows separation between development repo and deployment directory.

---

### PostgreSQL Configuration

These variables configure PostgreSQL database connections. If not set, scripts will use PostgreSQL's default values.

#### PGHOST
- **Required**: No (for PostgreSQL scripts)
- **Description**: PostgreSQL server hostname or IP address
- **Format**: Hostname or IP address
- **Default**: `localhost`
- **Example**: `192.168.1.100` or `db.example.com`
- **Used By**:
  - `scripts/Verify-Environment.ps1`
  - `scripts/Initialize-Configuration.ps1`
  - PostgreSQL backup scripts
  - Database DDL scripts

#### PGPORT
- **Required**: No
- **Description**: PostgreSQL server port
- **Format**: Integer (1-65535)
- **Default**: `5432` (PostgreSQL standard port)
- **Example**: `5433`
- **Used By**: PostgreSQL connection scripts

#### PGUSER
- **Required**: No
- **Description**: PostgreSQL username for authentication
- **Format**: String
- **Default**: `postgres` (PostgreSQL default superuser)
- **Example**: `myuser` or `backup_user`
- **Used By**: PostgreSQL connection scripts

#### PGDATABASE
- **Required**: No
- **Description**: Default PostgreSQL database to connect to
- **Format**: String (database name)
- **Default**: `postgres`
- **Example**: `gnucash` or `timeline`
- **Used By**: Database scripts

#### PGPASSWORD
- **Required**: No (for automated backups)
- **Description**: PostgreSQL password for authentication
- **Format**: String
- **Security**: ⚠️ **KEEP SECRET** - Never commit to git
- **Note**: Consider using `.pgpass` file instead for better security
  - `.pgpass` format: `hostname:port:database:username:password`
  - Location: `~/.pgpass` (Linux/Mac) or `%APPDATA%\postgresql\pgpass.conf` (Windows)
  - Permissions: Must be 0600 (read/write for owner only)
- **Used By**: Automated backup scripts

#### PGBACKUP_PASSWORD_FILE
- **Required**: No (for GnuCash backup script)
- **Description**: Path to encrypted PostgreSQL backup password file
- **Format**: Absolute file path
- **Default**: `config/secrets/pgbackup_user_pwd.txt`
- **Example**: `C:\Scripts\config\secrets\pgbackup_user_pwd.txt`
- **Used By**: `src/powershell/backup/Backup-GnuCashDatabase.ps1` (lines 42-43)
- **Note**: This file should contain the encrypted password for PostgreSQL backup operations

---

### Backup Configuration

#### BACKUP_RETENTION_DAYS
- **Required**: No
- **Description**: Number of days to retain database backups before automatic deletion
- **Format**: Integer (positive number)
- **Default**: `30`
- **Example**: `90` (3 months) or `7` (1 week)
- **Used By**:
  - `scripts/Verify-Environment.ps1` (lines 56-58)
  - PostgreSQL backup scripts
  - Backup cleanup utilities

---

### Logging Configuration

#### LOG_LEVEL
- **Required**: No
- **Description**: Minimum logging level for all scripts
- **Format**: String (one of: DEBUG, INFO, WARNING, ERROR, CRITICAL)
- **Default**: `INFO`
- **Values**:
  - `DEBUG` (10): Detailed diagnostic information
  - `INFO` (20): General informational messages (recommended for normal use)
  - `WARNING` (30): Warning messages for potentially problematic situations
  - `ERROR` (40): Error messages for failures
  - `CRITICAL` (50): Critical errors that may cause script termination
- **Example**: `DEBUG` (for troubleshooting) or `WARNING` (for quieter logs)
- **Used By**:
  - `scripts/Verify-Environment.ps1` (line 49)
  - All Python scripts using the logging framework
  - PowerShell scripts with logging framework integration

#### LOG_DIR
- **Required**: No
- **Description**: Custom directory for log files
- **Format**: Absolute directory path
- **Default**: `./logs` (relative to script execution directory)
- **Example**: `C:\Logs\MyScripts` or `/var/log/my-scripts`
- **Used By**:
  - `scripts/Verify-Environment.ps1` (line 52)
  - All scripts using the logging framework
- **Note**: Directory will be created automatically if it doesn't exist

#### LOG_RETENTION_DAYS
- **Required**: No
- **Description**: Number of days to retain log files before automatic cleanup
- **Format**: Integer (positive number)
- **Default**: `90`
- **Example**: `30` (1 month) or `365` (1 year)
- **Used By**: Log purge utilities and cleanup scripts

---

### Email Notifications (Optional)

These variables enable email notifications for script execution results and errors. All are optional.

#### SMTP_SERVER
- **Required**: No (only if using email notifications)
- **Description**: SMTP server hostname for sending emails
- **Format**: Hostname or IP address
- **Example**: `smtp.gmail.com` or `mail.example.com`
- **Used By**: Email notification utilities

#### SMTP_PORT
- **Required**: No
- **Description**: SMTP server port
- **Format**: Integer (1-65535)
- **Default**: `587` (STARTTLS standard port)
- **Common Ports**:
  - `587` - STARTTLS (recommended)
  - `465` - SSL/TLS
  - `25` - Unencrypted (not recommended)
- **Example**: `587`
- **Used By**: Email notification utilities

#### SMTP_USERNAME
- **Required**: No
- **Description**: SMTP authentication username
- **Format**: String (usually an email address)
- **Example**: `notifications@example.com`
- **Used By**: Email notification utilities

#### SMTP_PASSWORD
- **Required**: No
- **Description**: SMTP authentication password
- **Format**: String
- **Security**: ⚠️ **KEEP SECRET** - Never commit to git
- **Note**: For Gmail, use an App Password instead of your main password
- **Used By**: Email notification utilities

#### NOTIFICATION_EMAIL
- **Required**: No
- **Description**: Recipient email address for notifications
- **Format**: Email address
- **Example**: `admin@example.com` or `your.email@gmail.com`
- **Used By**: Email notification utilities

---

### Advanced Settings

#### PARALLEL_JOBS
- **Required**: No
- **Description**: Number of concurrent jobs for parallel processing operations
- **Format**: Integer (1-16)
- **Default**: `4`
- **Example**: `8` (for systems with many CPU cores) or `2` (for slower systems)
- **Used By**: Parallel processing utilities and batch operations
- **Note**: Higher values may improve performance on multi-core systems but increase memory usage

#### ENABLE_TELEMETRY
- **Required**: No
- **Description**: Enable anonymous usage telemetry to help improve scripts
- **Format**: Boolean (true or false)
- **Default**: `false`
- **Values**:
  - `true` - Send anonymous usage statistics
  - `false` - Disable telemetry
- **Example**: `true`
- **Used By**: Telemetry collection utilities
- **Note**: Telemetry is anonymous and helps improve script reliability

---

## CI/CD Secrets (GitHub Actions)

These are configured in GitHub repository settings, **not in your local .env file**.

### CODECOV_TOKEN
- **Required**: Yes (for CI)
- **Description**: Codecov upload token for coverage reports
- **Where**: GitHub → Settings → Secrets and variables → Actions → New repository secret
- **How to Get**:
  1. Go to https://codecov.io
  2. Sign in with GitHub
  3. Navigate to your repository
  4. Go to Settings → General
  5. Copy the "Repository Upload Token"
- **Used By**: `.github/workflows/sonarcloud.yml` (lines 70, 129)

### SONAR_TOKEN
- **Required**: Yes (for CI)
- **Description**: SonarCloud analysis token
- **Where**: GitHub → Settings → Secrets and variables → Actions → New repository secret
- **How to Get**:
  1. Go to https://sonarcloud.io
  2. Sign in with GitHub
  3. Go to My Account → Security
  4. Generate a new token
  5. Copy the token
- **Used By**: `.github/workflows/sonarcloud.yml` (lines 233, 239)

### GITHUB_TOKEN
- **Required**: Automatic
- **Description**: GitHub Actions authentication token
- **Note**: Provided automatically by GitHub Actions - no configuration needed
- **Used By**:
  - `.github/workflows/release.yml`
  - `.github/workflows/sonarcloud.yml`
  - `.github/workflows/label-inherit.yml`
- **Permissions**: Configured per workflow in workflow file

---

## Standard OS Environment Variables

These are standard operating system environment variables that scripts may use. You typically don't need to set these manually.

### Windows Environment Variables

| Variable | Description | Used In |
|----------|-------------|---------|
| **USERNAME** | Current Windows username | Git hooks, deployment scripts, Task Scheduler installation |
| **USERPROFILE** | User's home directory (e.g., `C:\Users\Username`) | File cleanup, backup sync, configuration initialization |
| **USERDOMAIN** | Windows domain name | System health check task installation |
| **SystemRoot** | Windows system root (e.g., `C:\Windows`) | System health checks, Python error handling |
| **SystemDrive** | System drive letter (e.g., `C:`) | System health checks |
| **LOCALAPPDATA** | Local application data directory | File cleanup utilities |
| **TEMP** | Temporary files directory | File cleanup utilities |
| **ProgramFiles** | Program Files directory | Module deployment |
| **PSModulePath** | PowerShell module search paths | Module deployment configuration |

---

## Setup Instructions

### Development Environment

1. **Copy example file**:
   ```bash
   cp .env.example .env
   ```

2. **Edit .env file** with your values:
   ```bash
   # Windows
   notepad .env

   # Linux/Mac
   nano .env
   # or
   vim .env
   ```

3. **Set required variables** (at minimum):
   ```bash
   MY_SCRIPTS_ROOT=C:\Users\YourName\Documents\Scripts  # Windows
   # or
   MY_SCRIPTS_ROOT=/home/yourname/Documents/Scripts     # Linux/Mac
   ```

4. **Set feature-specific variables** (only if using those features):
   ```bash
   # Google Drive (if using Google Drive scripts)
   GDRIVE_CREDENTIALS_PATH=C:\Scripts\credentials.json

   # CloudConvert (if using conversion scripts)
   CLOUDCONVERT_PROD=your_api_key_here

   # PostgreSQL (if using database scripts)
   PGHOST=localhost
   PGPORT=5432
   PGUSER=postgres
   ```

5. **Validate configuration**:
   ```powershell
   pwsh ./scripts/Verify-Environment.ps1
   ```

6. **Test with a script**:
   ```powershell
   # Test Python script
   python src/python/data/csv_to_gpx.py --help

   # Test PowerShell script
   pwsh src/powershell/system/Remove-OldDownload.ps1 -DaysOld 30 -DryRun
   ```

### Interactive Configuration Wizard

For a guided setup experience:

```powershell
pwsh ./scripts/Initialize-Configuration.ps1
```

This wizard will:
- Prompt for required variables
- Set up PostgreSQL configuration
- Create necessary directories
- Validate your configuration

### CI/CD Environment

Configure secrets in GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add the following secrets:
   - `CODECOV_TOKEN` - From Codecov.io
   - `SONAR_TOKEN` - From SonarCloud.io
4. `GITHUB_TOKEN` is provided automatically

### Production/Scheduled Tasks

For Windows Task Scheduler or production deployments:

**Option 1: System Environment Variables**
1. Open System Properties → Advanced → Environment Variables
2. Add variables under "System variables" (for all users) or "User variables" (for current user)
3. Restart any running scripts/services

**Option 2: Task Scheduler with Load-Environment.ps1**
```powershell
# In your scheduled task, add this before the main script:
. C:\Scripts\scripts\Load-Environment.ps1
python C:\Scripts\src\python\cloud\gdrive_backup.py
```

**Option 3: Hardcode in Task Definition**
- In Task Scheduler, go to Actions → Edit
- Add environment variables in the "Add arguments" field:
  ```powershell
  -Command "& { $env:MY_SCRIPTS_ROOT='C:\Scripts'; & 'C:\Scripts\script.ps1' }"
  ```

---

## Security Best Practices

### Never Commit Secrets

**Always verify .env is in .gitignore:**
```bash
# Check .gitignore
grep "^\.env$" .gitignore

# Should show: .env
```

**If you accidentally committed secrets:**
1. Immediately rotate the compromised keys/passwords
2. Remove from git history:
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch .env" \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. Force push (⚠️ coordinate with team)
4. Verify secrets are gone: `git log --all --full-history -- .env`

### Use Different Keys Per Environment

- **Development**: Use sandbox/test API keys with limited permissions
- **Staging**: Use separate staging keys
- **Production**: Use production API keys with appropriate restrictions
- **Never share production keys** between environments

Example:
```bash
# .env (development)
CLOUDCONVERT_PROD=sandbox_key_abc123

# Production server
CLOUDCONVERT_PROD=production_key_xyz789
```

### Rotate Keys Regularly

- **Rotate API keys every 90 days** as best practice
- **Rotate immediately** after:
  - Team member departure
  - Suspected key exposure
  - Security incident
  - Third-party breach
- **Set calendar reminders** for regular rotation

### File Permissions

Ensure .env file has restricted permissions:

```bash
# Linux/Mac - Only owner can read/write
chmod 600 .env

# Verify
ls -la .env
# Should show: -rw------- (600)

# Windows - Remove inheritance and grant only to current user
icacls .env /inheritance:r
icacls .env /grant:r "%USERNAME%:F"
```

### Use Secret Management Tools

For production deployments, consider:

**Windows:**
- **Windows Credential Manager**: `cmdkey` command
- **DPAPI**: Data Protection API for encrypting secrets

**macOS:**
- **Keychain**: Store secrets securely in macOS Keychain

**Linux:**
- **Secret Service**: GNOME Keyring or KWallet
- **pass**: Standard Unix password manager

**Cross-Platform/Teams:**
- **HashiCorp Vault**: Enterprise secret management
- **Azure Key Vault**: Cloud-based secret storage
- **AWS Secrets Manager**: For AWS deployments
- **1Password/LastPass**: Team password managers with CLI

**Example using Windows Credential Manager:**
```powershell
# Store secret
cmdkey /generic:MyScripts_CloudConvert /user:apikey /pass:your_api_key

# Retrieve in script
$cred = cmdkey /list:MyScripts_CloudConvert
```

### Environment-Specific .env Files

Consider using separate .env files per environment:

```bash
.env.development   # Development settings
.env.staging       # Staging settings
.env.production    # Production settings (never commit!)
```

Load the appropriate file in your scripts:
```bash
# Load environment-specific file
ENV_FILE=".env.${ENVIRONMENT:-development}"
source "$ENV_FILE"
```

---

## Troubleshooting

### "Environment variable not found"

**Symptoms:**
- Script fails with "Variable not set" or "Cannot find variable"
- Error message: `The term '$env:VARIABLE_NAME' is not recognized`

**Solutions:**

1. **Check .env file exists:**
   ```bash
   # PowerShell
   Test-Path .env

   # Bash
   test -f .env && echo "exists" || echo "missing"
   ```

2. **Check variable is set:**
   ```powershell
   # PowerShell
   echo $env:VARIABLE_NAME

   # Bash
   echo $VARIABLE_NAME
   ```

3. **Check for spelling errors:**
   - Variable names are case-sensitive on Linux/Mac
   - Verify exact spelling matches .env.example

4. **Run environment verification:**
   ```powershell
   pwsh ./scripts/Verify-Environment.ps1
   ```

5. **Load .env file manually:**
   ```powershell
   # PowerShell
   . ./scripts/Load-Environment.ps1

   # Bash
   source ./scripts/load-environment.sh
   ```

6. **Check for extra whitespace:**
   ```bash
   # Bad (has space after =)
   MY_SCRIPTS_ROOT= C:\Scripts

   # Good (no space)
   MY_SCRIPTS_ROOT=C:\Scripts
   ```

### "Invalid credentials" or "Authentication failed"

**Symptoms:**
- Google Drive: "invalid_client" or "invalid_grant"
- CloudConvert: "Unauthorized" or "Invalid API key"
- PostgreSQL: "password authentication failed"

**Solutions:**

1. **Verify API key/credentials are correct:**
   - Copy the key again from the source
   - Check for truncation or extra characters

2. **Check for extra spaces/newlines:**
   ```bash
   # View the actual content
   cat .env | grep CLOUDCONVERT_PROD

   # Should be on one line with no extra spaces
   ```

3. **Ensure key hasn't expired:**
   - Google Drive: Check if OAuth credentials are still valid
   - CloudConvert: Check if API key is active in dashboard
   - Regenerate if necessary

4. **Test key directly via API:**
   ```bash
   # CloudConvert API test
   curl -H "Authorization: Bearer YOUR_API_KEY" \
        https://api.cloudconvert.com/v2/users/me
   ```

5. **For Google Drive, re-authenticate:**
   ```bash
   # Delete old token
   rm ~/Documents/Scripts/drive_token.json

   # Run script to re-authenticate
   python src/python/cloud/google_drive_auth.py
   ```

6. **Check OAuth consent screen:**
   - Ensure your app is not in "Testing" mode with expired test users
   - Verify required scopes are enabled

### Scripts can't find .env file

**Symptoms:**
- Script runs but environment variables are empty/not loaded
- Error: "Cannot find .env file"

**Solutions:**

1. **Run scripts from repository root:**
   ```bash
   # Wrong (from subdirectory)
   cd src/python/cloud
   python gdrive_backup.py

   # Correct (from repository root)
   cd /path/to/My-Scripts
   python src/python/cloud/gdrive_backup.py
   ```

2. **Use absolute paths in .env:**
   ```bash
   # Relative path (may not work)
   GDRIVE_CREDENTIALS_PATH=./credentials.json

   # Absolute path (recommended)
   GDRIVE_CREDENTIALS_PATH=C:\Users\YourName\Documents\Scripts\credentials.json
   ```

3. **Explicitly load environment in scripts:**
   ```powershell
   # Add to beginning of PowerShell scripts
   . "$PSScriptRoot\..\..\scripts\Load-Environment.ps1"
   ```

4. **Check .env file location:**
   ```bash
   # .env should be in repository root
   My-Scripts/
   ├── .env              ← Here
   ├── .env.example
   ├── src/
   └── scripts/
   ```

### "Permission denied" when accessing credentials file

**Symptoms:**
- Error: "Permission denied: 'credentials.json'"
- Error: "Access is denied"

**Solutions:**

1. **Check file permissions:**
   ```bash
   # Linux/Mac
   ls -la credentials.json
   chmod 600 credentials.json

   # Windows (PowerShell)
   icacls credentials.json
   ```

2. **Verify file path is correct:**
   ```bash
   # Test if file exists and is readable
   test -r credentials.json && echo "OK" || echo "Cannot read"
   ```

3. **Run script with appropriate permissions:**
   ```bash
   # Windows: Run PowerShell as Administrator (if needed)
   # Linux: Check if you need sudo (generally not recommended for user scripts)
   ```

### PostgreSQL connection fails

**Symptoms:**
- Error: "could not connect to server"
- Error: "FATAL: password authentication failed"

**Solutions:**

1. **Verify PostgreSQL is running:**
   ```bash
   # Linux
   sudo systemctl status postgresql

   # Windows
   Get-Service postgresql*
   ```

2. **Check connection parameters:**
   ```bash
   # Test connection manually
   psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE
   ```

3. **Verify pg_hba.conf allows connections:**
   - Check PostgreSQL configuration for authentication method
   - Ensure your IP/host is allowed

4. **Use .pgpass file for password:**
   ```bash
   # Create .pgpass file
   echo "localhost:5432:*:postgres:your_password" > ~/.pgpass
   chmod 600 ~/.pgpass
   ```

### Logs not appearing in expected location

**Symptoms:**
- Scripts run but no log files created
- Logs appear in wrong directory

**Solutions:**

1. **Check LOG_DIR variable:**
   ```bash
   echo $env:LOG_DIR  # PowerShell
   echo $LOG_DIR      # Bash
   ```

2. **Verify directory exists and is writable:**
   ```bash
   test -w ./logs && echo "writable" || echo "not writable"
   ```

3. **Check script is using logging framework:**
   - Verify script imports `PowerShellLoggingFramework.psm1` or `python_logging_framework`

4. **Run with DEBUG logging:**
   ```bash
   # Set LOG_LEVEL temporarily
   export LOG_LEVEL=DEBUG  # Bash
   $env:LOG_LEVEL="DEBUG"  # PowerShell
   ```

---

## Validation Script

The repository includes a comprehensive validation script to check your environment configuration:

**Location:** `scripts/Verify-Environment.ps1`

**Usage:**
```powershell
# Basic validation
pwsh ./scripts/Verify-Environment.ps1

# With verbose output
pwsh ./scripts/Verify-Environment.ps1 -Verbose
```

**What it checks:**
- ✅ Required variables (MY_SCRIPTS_ROOT)
- ✅ Optional variables with defaults (LOG_LEVEL, LOG_DIR, BACKUP_RETENTION_DAYS)
- ✅ Feature-specific configurations (Google Drive, CloudConvert, PostgreSQL)
- ✅ File existence (credentials files, token files)
- ✅ Directory accessibility
- ✅ Value formats and ranges

**Exit codes:**
- `0` - All checks passed
- `1` - Validation failed (see output for details)

---

## Related Documentation

- **[Installation Guide](../INSTALLATION.md)** - Complete installation instructions
- **[Configuration Guide](../config/CONFIG_GUIDE.md)** - Detailed configuration documentation
- **[Contributing Guidelines](../CONTRIBUTING.md)** - Development standards and practices
- **[Security Best Practices](../CONTRIBUTING.md#security)** - Security guidelines

---

## Quick Reference Tables

### Required Variables Summary

| Variable | Purpose | Where to Get |
|----------|---------|--------------|
| `MY_SCRIPTS_ROOT` | Script execution directory | Choose a directory on your system |
| `GDRIVE_CREDENTIALS_PATH` | Google Drive OAuth credentials | https://console.cloud.google.com/apis/credentials |
| `CLOUDCONVERT_PROD` | CloudConvert API key | https://cloudconvert.com/dashboard/api/v2/keys |

### Optional Variables Summary

| Variable | Default | Purpose |
|----------|---------|---------|
| `GDRIVE_TOKEN_PATH` | `~/Documents/Scripts/drive_token.json` | Google Drive token cache |
| `PGHOST` | `localhost` | PostgreSQL server |
| `PGPORT` | `5432` | PostgreSQL port |
| `PGUSER` | `postgres` | PostgreSQL user |
| `LOG_LEVEL` | `INFO` | Logging verbosity |
| `LOG_DIR` | `./logs` | Log file directory |
| `LOG_RETENTION_DAYS` | `90` | Log retention period |
| `BACKUP_RETENTION_DAYS` | `30` | Backup retention period |
| `PARALLEL_JOBS` | `4` | Concurrent job count |

### CI/CD Variables Summary

| Variable | Where to Configure | Required |
|----------|-------------------|----------|
| `CODECOV_TOKEN` | GitHub Secrets | Yes (for CI) |
| `SONAR_TOKEN` | GitHub Secrets | Yes (for CI) |
| `GITHUB_TOKEN` | Auto-provided | Yes (automatic) |

---

## Version History

- **v1.0.0** (2025-12-06): Initial comprehensive environment variable documentation
  - Documented 23 application-defined variables
  - Documented 9 OS environment variables
  - Documented 3 CI/CD secrets
  - Added security best practices
  - Added troubleshooting guide
  - Added quick reference tables

---

**Last Updated:** 2025-12-06
**Maintained By:** My-Scripts Repository
**Related Issue:** #606 (Phase 1 of #010: Environment Variable Management)
