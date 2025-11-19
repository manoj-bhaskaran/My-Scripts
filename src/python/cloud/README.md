# Cloud Services Scripts

Python scripts for cloud service integration, primarily Google Drive operations.

## Scripts

- **gdrive_recover.py** - Google Drive file recovery and restoration utilities
- **google_drive_root_files_delete.py** - Cleans up files in Google Drive root directory
- **drive_space_monitor.py** - Monitors Google Drive storage usage and sends alerts
- **cloudconvert_utils.py** - CloudConvert API utilities for file conversion

## Dependencies

### Python Modules
- **python_logging_framework** (`src/python/modules/logging/`) - Standardized logging
- **google_drive_auth** (`src/python/modules/auth/`) - Google Drive authentication

### External Packages
```bash
pip install google-auth google-auth-oauthlib google-auth-httplib2
pip install google-api-python-client
pip install requests
```

## Configuration

### Google Drive Authentication

Scripts using Google Drive require OAuth2 credentials:

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Google Drive API
3. Create OAuth2 credentials
4. Download credentials file
5. Configure path to credentials in scripts or environment variables

### CloudConvert API

CloudConvert scripts require an API key:
- Set environment variable `CLOUDCONVERT_API_KEY`
- Or configure in script parameters

## Scheduling

The Drive Space Monitor script can be scheduled via Windows Task Scheduler:
- Task definition: `config/tasks/Drive Space Monitor.xml`

## Use Cases

### Drive Space Management
Monitor storage usage and receive alerts before reaching quota limits.

### File Organization
Move files out of Drive root into organized folders.

### File Recovery
Recover deleted or lost files from Google Drive trash.

## Logging

All scripts use the Python Logging Framework located in `src/python/modules/logging/`.
