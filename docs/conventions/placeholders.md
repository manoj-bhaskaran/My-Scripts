# Documentation Placeholders

This document defines standard placeholders to use in all documentation examples. Using consistent placeholders ensures documentation works for all users and maintains a professional appearance.

## Path Placeholders

Use these standard placeholders in all documentation:

| Placeholder | Description | Windows Example | Linux Example |
|------------|-------------|-----------------|---------------|
| `<REPO_PATH>` | Git repository location | `C:\Projects\My-Scripts` | `~/dev/My-Scripts` |
| `<SCRIPT_ROOT>` | Working/deployment directory | `C:\Users\YourName\Documents\Scripts` | `~/scripts` |
| `<CONFIG_DIR>` | Configuration directory | `C:\Users\YourName\AppData\Local\MyScripts` | `~/.config/myscripts` |
| `<LOG_DIR>` | Log file directory | `C:\Logs\MyScripts` | `/var/log/myscripts` |
| `<BACKUP_DIR>` | Backup storage directory | `D:\Backups` | `~/backups` |
| `<USERNAME>` | Current user | `YourName` | `yourname` |

## Usage Guidelines

### General Rules

1. **Always use placeholders** instead of actual paths in examples
2. **Provide both Windows and Linux examples** when applicable
3. **Add a note** at the beginning of documentation explaining placeholders
4. **Use environment variables** as an alternative when appropriate
5. **Be consistent** across all documentation files

### Introducing Placeholders

Add this note at the beginning of documentation with examples:

```markdown
> **Note:** Examples in this guide use placeholder paths like `<REPO_PATH>` and `<SCRIPT_ROOT>`.
> Replace these with your actual paths:
> - `<REPO_PATH>` → Your repository location (e.g., `C:\Projects\My-Scripts` on Windows or `~/dev/My-Scripts` on Linux)
> - `<SCRIPT_ROOT>` → Your working directory (e.g., `C:\Users\YourName\Documents\Scripts` on Windows or `~/scripts` on Linux)
```

## Usage Examples

### PowerShell Examples

#### Good Examples ✅

```powershell
# Example 1: Using placeholders
cd "<SCRIPT_ROOT>"
.\src\powershell\Invoke-SystemHealthCheck.ps1

# Example 2: Using environment variables (preferred)
cd "$env:MY_SCRIPTS_ROOT"
.\src\powershell\Invoke-SystemHealthCheck.ps1

# Example 3: Sync repository to deployment directory
.\Sync-Directory.ps1 -Source "<REPO_PATH>" -Destination "<SCRIPT_ROOT>"
```

#### Bad Examples ❌

```powershell
# DO NOT use actual paths
cd "C:\Users\manoj\Documents\Scripts"
.\src\powershell\Invoke-SystemHealthCheck.ps1

# DO NOT use hardcoded usernames or drive letters
.\Sync-Directory.ps1 -Source "D:\My Scripts" -Destination "C:\Users\manoj\Documents\Scripts"
```

### Bash Examples

#### Good Examples ✅

```bash
# Example 1: Using placeholders
cd "<SCRIPT_ROOT>"
./src/sh/system-health-check.sh

# Example 2: Using environment variables (preferred)
cd "$MY_SCRIPTS_ROOT"
./src/sh/system-health-check.sh

# Example 3: Clone repository
git clone https://github.com/yourusername/My-Scripts.git "<REPO_PATH>"
cd "<REPO_PATH>"
```

#### Bad Examples ❌

```bash
# DO NOT use actual paths
cd /home/manoj/scripts
./src/sh/system-health-check.sh

# DO NOT use hardcoded usernames
git clone https://github.com/yourusername/My-Scripts.git ~/manoj/dev/My-Scripts
```

### Configuration File Examples

#### Good Examples ✅

```json
{
  "enabled": true,
  "stagingMirror": "<SCRIPT_ROOT>",
  "backupDirectory": "<BACKUP_DIR>",
  "logDirectory": "<LOG_DIR>"
}
```

#### Bad Examples ❌

```json
{
  "enabled": true,
  "stagingMirror": "C:\\Users\\manoj\\Documents\\Scripts",
  "backupDirectory": "D:\\Backups",
  "logDirectory": "C:\\Logs"
}
```

## Environment Variables

When documenting setup, show users how to set environment variables:

### Windows (PowerShell)

```powershell
# Set environment variables for current session
$env:MY_SCRIPTS_ROOT = "<SCRIPT_ROOT>"
$env:MY_SCRIPTS_REPO = "<REPO_PATH>"

# Set permanently for current user
[Environment]::SetEnvironmentVariable("MY_SCRIPTS_ROOT", "<SCRIPT_ROOT>", "User")
[Environment]::SetEnvironmentVariable("MY_SCRIPTS_REPO", "<REPO_PATH>", "User")
```

### Linux/macOS (Bash)

```bash
# Set environment variables for current session
export MY_SCRIPTS_ROOT="<SCRIPT_ROOT>"
export MY_SCRIPTS_REPO="<REPO_PATH>"

# Set permanently (add to ~/.bashrc or ~/.zshrc)
echo 'export MY_SCRIPTS_ROOT="<SCRIPT_ROOT>"' >> ~/.bashrc
echo 'export MY_SCRIPTS_REPO="<REPO_PATH>"' >> ~/.bashrc
source ~/.bashrc
```

## Platform-Specific Examples

When providing platform-specific examples, use clear headers:

### Good Example ✅

```markdown
**Windows:**
```powershell
cd "<SCRIPT_ROOT>"
.\script.ps1
```

**Linux/macOS:**
```bash
cd "<SCRIPT_ROOT>"
./script.sh
```
```

## Special Cases

### Log File Paths

For log file locations, be generic:

```markdown
# Good
Logs are saved to: `<SCRIPT_ROOT>\logs\ScriptName_YYYYMMDD.log` (Windows) or `<SCRIPT_ROOT>/logs/ScriptName_YYYYMMDD.log` (Linux)

# Bad
Logs are saved to: `C:\Users\manoj\Documents\Scripts\logs\ScriptName_YYYYMMDD.log`
```

### Directory Structure

When showing directory structure, use placeholders:

```markdown
# Good
<REPO_PATH>/                 # Repository (development)
├── src/
├── config/
└── docs/

<SCRIPT_ROOT>/              # Working directory (deployment)
├── src/
├── config/
└── logs/

# Bad
D:\My Scripts/              # Repository (development)
├── src/
├── config/
└── docs/
```

## Validation

Before committing documentation changes:

1. **Search for hardcoded paths**: Look for patterns like `C:\Users\`, `D:\`, `/home/username`
2. **Run the documentation checker**: `pwsh scripts/Check-DocumentationPaths.ps1`
3. **Review CI output**: The CI pipeline will fail if hardcoded paths are detected
4. **Test examples**: Verify placeholders are clear and examples work with substitution

## References

- [Technical Writing Best Practices](https://developers.google.com/tech-writing)
- [Microsoft Documentation Style Guide](https://learn.microsoft.com/en-us/style-guide/)
- [Main CONTRIBUTING.md](../../CONTRIBUTING.md)

---

**Last Updated:** 2025-11-29
**Version:** 1.0.0
