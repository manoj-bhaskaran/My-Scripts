# Issue #001: Empty Catch Blocks in PowerShell Scripts

## Severity
**Medium** - Silent failure handling can mask errors and make debugging difficult

## Category
Code Quality / Error Handling

## Description
Multiple PowerShell scripts contain empty catch blocks (`catch { }`) that silently suppress exceptions without logging or handling them. This practice violates the repository's error handling standards and makes it difficult to diagnose issues when they occur.

## Locations
Found 33 occurrences across multiple files:

1. **src/powershell/git/Invoke-PostMergeHook.ps1:375**
   ```powershell
   try { $mergeBase = git -C $script:RepoPath merge-base ORIG_HEAD HEAD 2>$null } catch {}
   ```

2. **src/powershell/system/Remove-OldDownload.ps1:250**
   ```powershell
   catch { }
   ```

3. **src/powershell/file-management/Expand-ZipsAndClean.ps1:744**
   ```powershell
   try { $consoleWidth = $Host.UI.RawUI.WindowSize.Width } catch {}
   ```

4. **src/powershell/file-management/FileDistributor.ps1** - Multiple occurrences:
   - Line 506, 554, 1206, 1569, 1642, 1680, 1687, 1700, 1735, 2035, 2036, 2037

5. **src/powershell/system/Remove-DuplicateFiles.ps1** - Lines 132, 402

6. **src/powershell/modules/Media/Videoscreenshot/** - Multiple files:
   - Public/Start-VideoBatch.ps1:214
   - Private/Vlc.Process.ps1:229, 341, 350, 354, 360
   - Private/Cropper.Invoke.ps1:227
   - Private/Gdi.Capture.ps1:98, 121, 122, 157, 158
   - Private/Video.Fps.ps1:86
   - Private/IO.Helpers.ps1:53, 98

7. **src/powershell/modules/Core/Logging/PurgeLogs/Public/Clear-LogFile.ps1:99**

## Impact
- **Debugging Difficulty**: Silent failures make it impossible to diagnose issues in production
- **Data Loss Risk**: Operations may fail without user notification
- **Violation of Standards**: Contradicts the repository's error handling framework
- **Maintenance Burden**: Future developers cannot understand why operations failed

## Root Cause
These appear to be "best-effort" operations where failure is considered acceptable, but the lack of logging means:
1. No audit trail of what went wrong
2. No way to distinguish between expected and unexpected failures
3. Impossible to detect patterns of failures

## Recommended Solution

### Option 1: Add Logging (Preferred)
Replace empty catch blocks with minimal logging:
```powershell
catch {
    Write-Message -Level Debug -Message "Failed to get console width: $_" -LoggerName $LoggerName
}
```

### Option 2: Use -ErrorAction SilentlyContinue
For truly optional operations, use proper PowerShell error suppression:
```powershell
$consoleWidth = (Get-Host).UI.RawUI.WindowSize.Width -ErrorAction SilentlyContinue
```

### Option 3: Document the Suppression
At minimum, add a comment explaining why the error is intentionally suppressed:
```powershell
catch {
    # Intentionally suppressed: Console width unavailable in non-interactive mode
}
```

## Implementation Steps
1. Audit each empty catch block to determine intent
2. Classify as:
   - Critical operation (should log as Warning/Error)
   - Best-effort operation (should log as Debug)
   - Truly optional (consider -ErrorAction instead)
3. Update catch blocks with appropriate logging or error handling
4. Update PSScriptAnalyzer configuration if intentional suppressions are needed

## Acceptance Criteria
- [ ] All empty catch blocks reviewed and classified
- [ ] Critical operations have proper error logging
- [ ] Best-effort operations have debug-level logging
- [ ] Documentation added for intentionally suppressed errors
- [ ] PSScriptAnalyzer rule B110 reevaluated

## Related Issues
- Connects to test coverage goals (COVERAGE_ROADMAP.md Phase 3)
- Related to error handling standardization (ErrorHandling module)
- Connected to logging framework standards (logging_specification.md)

## Notes
The repository has `B110` (try-except-pass) skipped in `pyproject.toml` for Python, acknowledging this pattern exists. However, PowerShell has a more sophisticated logging framework that should be used instead of silent suppression.

## Priority
**Medium** - Should be addressed in next maintenance cycle, particularly for file I/O and database operations where silent failures could cause data loss.
