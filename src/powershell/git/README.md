# Git Operations Scripts

Scripts for Git automation, hooks, and repository management.

## Scripts

- **Remove-MergedGitBranch.ps1** - Removes local and remote branches that have been merged
- **Invoke-PostCommitHook.ps1** - Post-commit hook automation (runs after commits)
- **Invoke-PostMergeHook.ps1** - Post-merge hook automation (runs after merges)

## Dependencies

### PowerShell Modules
- **PowerShellLoggingFramework** (`src/powershell/modules/Core/Logging/`) - Structured logging

### External Tools
- Git 2.x or later
- PowerShell 5.1 or later

## Git Hooks

The hook scripts in this directory can be invoked from Git hooks. To set up:

1. Navigate to your repository's `.git/hooks/` directory
2. Create or edit the appropriate hook file (e.g., `post-commit`, `post-merge`)
3. Add a call to the corresponding PowerShell script

Example `post-commit` hook:
```bash
#!/bin/sh
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\My-Scripts\src\powershell\git\Invoke-PostCommitHook.ps1"
```

## Branch Cleanup

The `Remove-MergedGitBranch.ps1` script helps maintain repository hygiene by:
- Identifying branches that have been merged into main/master
- Offering to delete local branches
- Optionally removing corresponding remote branches
- Supporting dry-run mode that avoids pruning remote-tracking branches

## Logging

All scripts use the PowerShell Logging Framework and write logs to the standard logs directory. Use `-LogFile` on
`Remove-MergedGitBranch.ps1` to direct logs to a specific file path.
