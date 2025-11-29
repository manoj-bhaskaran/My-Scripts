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

### PostgreSQL Backup Password

The PostgreSQL backup scripts (`Backup-GnuCashDatabase.ps1` and `Backup-TimelineDatabase.ps1`) require an encrypted password file.

#### Creating the Password File

1. **Create the encrypted password file:**

   ```powershell
   # Navigate to this directory
   cd config/secrets

   # Create encrypted password file
   Read-Host "Enter pgbackup user password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "pgbackup_user_pwd.txt"
   ```

2. **Verify the file was created:**

   ```powershell
   Get-Item pgbackup_user_pwd.txt
   ```

   You should see a file containing an encrypted string.

3. **Test the backup script:**

   ```powershell
   # Run the backup script - it should automatically find the password file
   .\src\powershell\backup\Backup-GnuCashDatabase.ps1 -Verbose
   ```

#### Using a Custom Password File Location

If you want to store the password file in a different location, you have two options:

**Option 1: Set Environment Variable (Recommended)**

```powershell
# Set for current user (persists across sessions)
[Environment]::SetEnvironmentVariable("PGBACKUP_PASSWORD_FILE", "C:\path\to\your\password.txt", "User")

# Or set for current session only
$env:PGBACKUP_PASSWORD_FILE = "C:\path\to\your\password.txt"
```

**Option 2: Pass as Parameter**

```powershell
.\src\powershell\backup\Backup-GnuCashDatabase.ps1 -PasswordFile "C:\path\to\your\password.txt"
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
├── pgbackup_user_pwd.txt (PostgreSQL backup password - encrypted)
└── *.pwd (other encrypted password files)
```

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

### "Password file not found" Error

If you see this error, ensure:

1. The password file exists at `config/secrets/pgbackup_user_pwd.txt`
2. Or the `PGBACKUP_PASSWORD_FILE` environment variable is set correctly
3. Or you're passing the `-PasswordFile` parameter

### "Failed to read or decrypt password file" Error

This error indicates:

1. The password file is corrupted
2. The password file was created by a different Windows user
3. The file is not properly encrypted

**Solution:** Recreate the password file:

```powershell
Remove-Item config/secrets/pgbackup_user_pwd.txt -ErrorAction SilentlyContinue
Read-Host "Enter password" -AsSecureString | ConvertFrom-SecureString | Out-File -FilePath "config/secrets/pgbackup_user_pwd.txt"
```

### Password File Created on Different Machine

SecureString encryption is **user-specific** and **machine-specific**. If you move the repository to a different machine or user account, you must recreate the password file.

## Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `PGBACKUP_PASSWORD_FILE` | PostgreSQL backup password file location | `C:\secure\pgbackup.txt` |
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
