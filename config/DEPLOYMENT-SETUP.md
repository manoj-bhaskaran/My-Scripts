# Git Hooks Deployment Setup

This directory contains configuration for optional local deployments via git hooks.

## Overview

The repository includes post-commit and post-merge hooks that automatically sync changes to a local directory of your choice. This is useful for:

- Maintaining a working copy of scripts outside the repository
- Automatic deployment to a staging/production directory
- Keeping multiple machines in sync

## Features

- **Optional**: Deployment only happens if you configure it
- **Local**: Each user configures their own deployment paths
- **Flexible**: Enable/disable without removing configuration
- **Safe**: Respects .gitignore patterns during sync

## Setup Instructions

### 1. Copy the Configuration Template

```bash
cp config/local-deployment-config.json.example config/local-deployment-config.json
```

### 2. Edit Your Local Configuration

Edit `config/local-deployment-config.json` with your deployment path:

```json
{
  "stagingMirror": "C:\\Users\\YourUsername\\Documents\\Scripts",
  "enabled": true
}
```

**Configuration Options:**

- `stagingMirror`: Absolute path to the directory where files will be synced
  - Use double backslashes on Windows: `C:\\Users\\...`
  - Use forward slashes on Unix: `/home/user/...`
- `enabled`: Set to `false` to temporarily disable deployment without removing the config

### 3. Verify Hook Installation

The hooks are already installed in `.git/hooks/`. You can verify they exist:

```bash
ls -l .git/hooks/post-commit .git/hooks/post-merge
```

If they're missing, they will need to be recreated (contact the repository maintainer).

### 4. Test the Setup

Make a small change to any file and commit it:

```bash
echo "# Test" >> test.txt
git add test.txt
git commit -m "Test deployment"
```

Check that the file appears in your configured `stagingMirror` directory.

## How It Works

### Post-Commit Hook

After each commit, the hook:

1. Detects all files modified/added in the commit
2. Copies them to the staging mirror (preserving directory structure)
3. Removes deleted files from the staging mirror
4. Deploys PowerShell modules per `config/modules/deployment.txt`

### Post-Merge Hook

After each merge (including `git pull`), the hook:

1. Detects all files changed by the merge
2. Syncs them to the staging mirror
3. Removes deleted files
4. Deploys updated PowerShell modules

### Module Deployment

Separately from the file mirroring, the hooks also deploy PowerShell modules to system locations based on `config/modules/deployment.txt`. This is independent of the staging mirror feature.

## Troubleshooting

### Hook Not Running

**Symptoms:** No files copied after commit/merge

**Solutions:**
1. Ensure PowerShell is installed and available in PATH
   - Windows: `powershell.exe` or `pwsh`
   - Unix: `pwsh` (PowerShell Core)
2. Check that hooks are executable:
   ```bash
   chmod +x .git/hooks/post-commit .git/hooks/post-merge
   ```
3. Verify hook files exist and are not `.sample` files

### Configuration Errors

**Symptoms:** Hook runs but shows warnings/errors

**Solutions:**
1. Ensure `config/local-deployment-config.json` exists
2. Verify JSON syntax (no trailing commas, proper quoting)
3. Check that `stagingMirror` path exists or can be created
4. Use absolute paths, not relative paths

### Files Not Syncing

**Symptoms:** Hook runs successfully but files don't appear

**Solutions:**
1. Check if files are in `.gitignore` (they won't sync)
2. Verify the `stagingMirror` path is correct
3. Check file permissions on the destination directory
4. Look for errors in the hook log: `<stagingMirror>/git-post-action.log`

### Disable Deployment Temporarily

Set `enabled: false` in your `config/local-deployment-config.json`:

```json
{
  "stagingMirror": "C:\\Users\\YourUsername\\Documents\\Scripts",
  "enabled": false
}
```

## Security Notes

- `config/local-deployment-config.json` is git-ignored and never committed
- Each user maintains their own local configuration
- Deployment paths are never shared in the repository
- The staging mirror receives an exact copy of committed files only

## Advanced Usage

### Multiple Deployment Targets

Currently, the system supports one staging mirror per repository. If you need multiple targets, you can:

1. Use symbolic links/junctions to mirror to multiple locations
2. Modify the PowerShell scripts to support arrays of targets
3. Use the module deployment feature for system-wide PowerShell modules

### Customizing Hook Behavior

The PowerShell implementation scripts are located at:

- `src/powershell/git/Invoke-PostCommitHook.ps1`
- `src/powershell/git/Invoke-PostMergeHook.ps1`

You can modify these for custom behavior (e.g., running tests, notifications, etc.).

## Files in This Directory

- `local-deployment-config.json.example` - Template configuration file
- `local-deployment-config.json` - Your local configuration (git-ignored)
- `modules/deployment.txt` - PowerShell module deployment configuration
- `DEPLOYMENT-SETUP.md` - This documentation file
