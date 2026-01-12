# Secure Configuration Files

This directory stores sensitive configuration files that should **NEVER** be committed to version control.

## Important Security Notes

⚠️ **WARNING**: This directory is excluded from version control via `.gitignore`

✅ Files in this directory are automatically ignored by git
✅ Use Windows file permissions to restrict access to this directory
✅ Passwords are stored as SecureString (encrypted with Windows DPAPI)
❌ **NEVER** commit files from this directory to version control
❌ **NEVER** share password files via email, chat, or cloud storage

## Setup Instructions

### PostgreSQL Backup Authentication

The PostgreSQL backup scripts (`Backup-GnuCashDatabase.ps1`, `Backup-TimelineDatabase.ps1`, and `Backup-LiftSimulatorDatabase.ps1`) use PostgreSQL's `.pgpass` file for secure authentication.

#### Setting Up .pgpass Authentication

1. **Create the .pgpass file:**

   The default location is `%APPDATA%\postgresql\pgpass.conf` on Windows.

   ```powershell
   # Create the directory if it doesn't exist
   $pgpassDir = Join-Path $env:APPDATA "postgresql"
   if (-not (Test-Path $pgpassDir)) {
       New-Item -ItemType Directory -Path $pgpassDir -Force
   }

   # Create or edit the pgpass.conf file
   $pgpassFile = Join-Path $pgpassDir "pgpass.conf"
   notepad $pgpassFile
   ```

2. **Add database entries to .pgpass:**

   Each line should follow the format: `hostname:port:database:username:password`

   ```text
   localhost:5432:gnucash_db:backup_user:your_password_here
   localhost:5432:timeline_data:backup_user:your_password_here
   localhost:5432:lift_simulator:backup_user:your_password_here
   localhost:5432:*:backup_user:your_password_here
   ```

   You can use `*` as a wildcard for any field.

3. **Secure the .pgpass file:**

   Restrict file permissions to prevent unauthorized access:

   ```powershell
   $pgpassFile = Join-Path $env:APPDATA "postgresql\pgpass.conf"
   $acl = Get-Acl $pgpassFile
   $acl.SetAccessRuleProtection($true, $false)
   $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
   $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, "FullControl", "Allow")
   $acl.SetAccessRule($rule)
   Set-Acl $pgpassFile $acl
   ```

4. **Test the backup script:**

   ```powershell
   # Run the backup script - it should automatically use .pgpass
   .\src\powershell\backup\Backup-GnuCashDatabase.ps1 -Verbose
   ```

#### Using a Custom .pgpass Location

If you want to use a different location for your .pgpass file:

```powershell
# Set PGPASSFILE environment variable (persists across sessions)
[Environment]::SetEnvironmentVariable("PGPASSFILE", "C:\path\to\your\pgpass.conf", "User")

# Or set for current session only
$env:PGPASSFILE = "C:\path\to\your\pgpass.conf"
```

### Handle.exe Path (Optional)

If you use the `Get-FileHandle.ps1` script, you can configure the Handle.exe location:

1. **Download Handle.exe** from [Sysinternals](https://docs.microsoft.com/en-us/sysinternals/downloads/handle)

2. **Place it in one of these locations:**
   - `tools/Handle/handle.exe` (in repository)
   - Custom location (set via environment variable)

3. **Set environment variable** (if using custom location):

   ```powershell
   [Environment]::SetEnvironmentVariable("HANDLE_EXE_PATH", "C:\Tools\handle.exe", "User")
   ```

## File Structure

This directory may contain:

```
config/secrets/
├── README.md (this file)
└── *.pwd (legacy encrypted password files - no longer used by backup scripts)
```

Note: PostgreSQL backup scripts now use `.pgpass` authentication located at `%APPDATA%\postgresql\pgpass.conf` instead of files in this directory.

## Security Best Practices

### File Permissions

Restrict access to this directory:

```powershell
# Remove inherited permissions
$path = ".\config\secrets"
$acl = Get-Acl $path
$acl.SetAccessRuleProtection($true, $false)

# Add permission for current user only
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Apply the ACL
Set-Acl $path $acl
```

### Password Rotation

Regularly rotate passwords and update encrypted files:

```powershell
# Delete old password file
Remove-Item config/secrets/pgbackup_user_pwd.txt

# Create new password file with updated password
Read-Host "Enter new pgbackup user password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "config/secrets/pgbackup_user_pwd.txt"
```

### Backup Considerations

- ❌ **Do NOT** backup this directory to cloud storage
- ❌ **Do NOT** include this directory in unencrypted backups
- ✅ **Do** use encrypted backup solutions if backing up this directory
- ✅ **Do** maintain a secure offline backup of password files

## Troubleshooting

### "Missing .pgpass" Error

If you see this error, ensure:

1. The .pgpass file exists at `%APPDATA%\postgresql\pgpass.conf`
2. Or the `PGPASSFILE` environment variable is set to a valid path
3. The file has the correct format (see setup instructions above)

**Solution:** Create the .pgpass file:

```powershell
$pgpassDir = Join-Path $env:APPDATA "postgresql"
New-Item -ItemType Directory -Path $pgpassDir -Force -ErrorAction SilentlyContinue

$pgpassFile = Join-Path $pgpassDir "pgpass.conf"
@"
localhost:5432:gnucash_db:backup_user:your_password_here
localhost:5432:timeline_data:backup_user:your_password_here
localhost:5432:lift_simulator:backup_user:your_password_here
"@ | Out-File -FilePath $pgpassFile -Encoding ASCII
```

### "Authentication Failed" Error

If PostgreSQL authentication fails:

1. Verify the password in .pgpass is correct
2. Ensure the database name, username, and port match your PostgreSQL configuration
3. Test the connection manually: `psql -U backup_user -d gnucash_db`
4. Check PostgreSQL logs for authentication errors

### "Suspicious ACLs on .pgpass" Warning

This warning indicates that the .pgpass file has overly permissive access rights. Restrict access to the current user only (see step 3 in setup instructions).

### Moving .pgpass to Another Machine

Unlike encrypted SecureString files, .pgpass files are **portable** between machines. Simply copy the file and ensure proper file permissions are set on the target machine.

## Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `PGPASSFILE` | PostgreSQL .pgpass file location | `C:\secure\pgpass.conf` |
| `HANDLE_EXE_PATH` | Handle.exe utility location | `C:\Tools\handle.exe` |
| `SCRIPTS_OLD_ROOT1` | Old script root for task scheduler updates | `C:\OldScripts` |
| `TASK_SCHEDULER_OUTPUT` | Output directory for task scheduler XMLs | `C:\Tasks` |

## Related Documentation

- [PowerShell SecureString Documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/convertto-securestring)
- [Windows DPAPI Overview](https://docs.microsoft.com/en-us/dotnet/standard/security/how-to-use-data-protection)
- [Issue #513: Fix Hardcoded Paths](../../docs/issues/513-fix-hardcoded-paths.md)

## Support

If you encounter issues with secure configuration:

1. Check the script's verbose output: Add `-Verbose` parameter
2. Review the script's error messages for specific guidance
3. Ensure you're running PowerShell as the same user who created the encrypted files
4. Verify file permissions on the `config/secrets` directory
