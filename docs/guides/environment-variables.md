# Environment Variables

A centralized reference for all configuration variables used by My-Scripts. Copy `.env.example` to `.env`, fill in the values you need, then load them with the helper scripts:

- Bash: `source scripts/load-environment.sh`
- PowerShell: `. ./scripts/Load-Environment.ps1`

Use the validation commands to confirm your configuration:

- Bash: `./scripts/verify-environment.sh`
- PowerShell: `./scripts/Verify-Environment.ps1`

## Variable Reference

### Core Paths

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `MY_SCRIPTS_ROOT` | Yes | _None_ | Root directory where scripts run (task scheduler jobs target this path). |
| `MY_SCRIPTS_REPO` | No | Current directory | Local repository checkout (helpful for contributors). |

### Google Drive Integration

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `GDRIVE_CREDENTIALS_PATH` | When using Drive features | `~/Documents/Scripts/credentials.json` | OAuth client credentials downloaded from Google Cloud Console. |
| `GDRIVE_TOKEN_PATH` | When using Drive features | `~/Documents/Scripts/drive_token.json` | OAuth token cache written after the first login. |

### Google Drive Recovery Tool

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `GDRT_CREDENTIALS_FILE` | When using `gdrive_recover.py` | `GDRIVE_CREDENTIALS_PATH` or `./credentials.json` | Credentials file for recovery operations. |
| `GDRT_TOKEN_FILE` | No | `GDRIVE_TOKEN_PATH` or `./token.json` | OAuth token cache for recovery. Auto-created on first auth. |
| `GDRT_STRICT_POLICY` | No | `0` | Enable stricter recovery checks (`1` to enable). |

### CloudConvert

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `CLOUDCONVERT_PROD` | When using CloudConvert | _None_ | Production API key from the CloudConvert dashboard. |

### Database Backups

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `PGHOST` | No | `localhost` | PostgreSQL host name. |
| `PGPORT` | No | `5432` | PostgreSQL port. |
| `PGUSER` | No | `postgres` | PostgreSQL user. |
| `PGDATABASE` | No | `postgres` | Default database name. |
| `BACKUP_RETENTION_DAYS` | No | `30` | Days to retain backup files. |

### Logging

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `LOG_LEVEL` | No | `INFO` | Logging verbosity (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`). |
| `LOG_DIR` | No | `./logs` | Output directory for log files. |
| `LOG_RETENTION_DAYS` | No | `90` | Number of days to keep rotated logs. |

### Email Notifications (Optional)

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `SMTP_SERVER` | Only when sending mail | _None_ | SMTP server host. |
| `SMTP_PORT` | Only when sending mail | `587` | SMTP port. |
| `SMTP_USERNAME` | Only when sending mail | _None_ | SMTP login user. |
| `SMTP_PASSWORD` | Only when sending mail | _None_ | SMTP login password (store securely). |
| `NOTIFICATION_EMAIL` | Only when sending mail | _None_ | Recipient for notifications. |

### Advanced

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `PARALLEL_JOBS` | No | `4` | Number of concurrent jobs for workloads that support it. |
| `ENABLE_TELEMETRY` | No | `false` | Enable anonymous usage telemetry. |

## Tips

- Run the validation scripts after editing `.env` to catch missing or invalid values early.
- Keep secrets like API keys out of version control—`.env` is ignored by Git.
- Use absolute paths for credential files to avoid ambiguity in scheduled tasks.
- When running on CI or ephemeral hosts, set required variables as step-level environment variables instead of committing them to disk.
