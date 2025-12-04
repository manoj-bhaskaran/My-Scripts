# Issue #002: Write-Host Usage in PowerShell Scripts

## Severity
**Low** - Code quality issue, but doesn't affect functionality

## Category
Code Quality / Best Practices

## Description
Multiple PowerShell scripts use `Write-Host` instead of proper output streams or the logging framework. While `Write-Host` works, it:
- Cannot be redirected or captured
- Bypasses PowerShell's output pipeline
- Is not suitable for production scripts
- Is inconsistent with the repository's logging framework

## Locations
Found 30+ occurrences, primarily in:

### 1. Test Scripts (Acceptable)
- **improved-test-sanitizes-author.ps1** - Mock debugging output (Lines 27, 30, 34, 38, 44)
  - These are acceptable as they're for test diagnostics

### 2. Utility Scripts (Should be Updated)
- **scripts/Load-Environment.ps1** (Lines 10, 35)
  - User-facing messages about environment loading
  - Should use `Write-Information` or logging framework

- **scripts/Check-DocumentationPaths.ps1** (Lines 47-152)
  - Extensive use of Write-Host for reporting
  - This is a diagnostic tool, so Write-Host may be acceptable
  - However, should consider structured output for automation

## Impact
- **Pipeline Integration**: Output cannot be captured or redirected
- **Automation Issues**: Difficult to parse output in automated scripts
- **Inconsistency**: Violates established logging patterns
- **User Experience**: No control over verbosity levels

## Exceptions
Write-Host is acceptable in:
1. **Interactive-only scripts** - Where user feedback is the primary purpose
2. **Test/Mock output** - For debugging test execution
3. **Color-coded reporting tools** - Like Check-DocumentationPaths.ps1

## Recommended Solution

### For Production Scripts
Replace `Write-Host` with appropriate alternatives:

**Information messages:**
```powershell
# Before
Write-Host "Environment loaded from $envFile" -ForegroundColor Green

# After
Write-Information "Environment loaded from $envFile" -InformationAction Continue
# Or use the logging framework:
Write-Message -Level Info -Message "Environment loaded from $envFile" -LoggerName $LoggerName
```

**Error messages:**
```powershell
# Before
Write-Host "Error: File not found" -ForegroundColor Red

# After
Write-Error "File not found"
# Or:
Write-Message -Level Error -Message "File not found" -LoggerName $LoggerName
```

**Warnings:**
```powershell
# Before
Write-Host "WARNING: Configuration missing" -ForegroundColor Yellow

# After
Write-Warning "Configuration missing"
```

### For Diagnostic/Interactive Tools
Document that Write-Host is intentional:
```powershell
# Using Write-Host for color-coded interactive reporting (intentional)
Write-Host "Checking documentation paths..." -ForegroundColor Cyan
```

## Implementation Steps
1. Categorize Write-Host usage:
   - Production scripts → Replace with logging framework
   - Utility/diagnostic scripts → Replace with Write-Information
   - Interactive/reporting tools → Document as intentional
   - Test scripts → Leave as-is
2. Add PSScriptAnalyzer suppression for intentional uses
3. Update scripts to use logging framework
4. Document output stream strategy in contributing guide

## Acceptance Criteria
- [ ] All production scripts use proper logging framework
- [ ] Utility scripts use Write-Information or logging
- [ ] Intentional Write-Host usage is documented
- [ ] PSScriptAnalyzer suppressions added where needed
- [ ] Output strategy documented in CONTRIBUTING.md

## Related Files
- `src/powershell/modules/Core/Logging/PowerShellLoggingFramework/`
- `docs/logging_specification.md`
- `CONTRIBUTING.md`

## Code Review Rule
Add to code review checklist:
- [ ] New scripts use logging framework instead of Write-Host
- [ ] Write-Host usage is justified and documented

## Priority
**Low** - Cosmetic issue, address during code review or refactoring. Not blocking for functionality.

## References
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- [Write-Host Considered Harmful](https://www.jsnover.com/blog/2013/12/07/write-host-considered-harmful/)
- Repository logging specification: `docs/logging_specification.md`
