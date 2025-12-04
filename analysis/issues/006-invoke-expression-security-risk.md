# Issue #006: Invoke-Expression Security Risk in PowerShell

## Severity
**Medium** - Potential security vulnerability and bad practice

## Category
Security / Code Quality

## Description
The PowerShell script `Verify-Installation.ps1` uses `Invoke-Expression` to execute dynamically constructed commands. This is considered a security anti-pattern and is flagged by PSScriptAnalyzer because:
- It can lead to code injection vulnerabilities
- Makes code harder to analyze and debug
- Difficult to test properly
- Can execute arbitrary code if input is not properly sanitized

## Location
**scripts/Verify-Installation.ps1:62**
```powershell
$output = Invoke-Expression $Command 2>$null
```

**Context**: The script is checking for installed tools (Git, Python, PostgreSQL, etc.) by executing version commands.

## Additional Occurrences
Found 20+ mock usages in test files (acceptable for testing):
- `tests/powershell/unit/PostgresBackup.Tests.ps1` (17 occurrences - mocking only)
- These are test mocks and are appropriate

## Impact

### Security Risks
- **Code Injection**: If `$Command` variable is influenced by external input, arbitrary code could be executed
- **Privilege Escalation**: Commands run with same privileges as script
- **Unpredictable Behavior**: String construction can lead to parsing issues

### Code Quality Issues
- **Poor Testability**: Hard to mock and test
- **Difficult Debugging**: Harder to set breakpoints and trace
- **Static Analysis**: PSScriptAnalyzer cannot analyze dynamically executed code

## Current Implementation
```powershell
# Verify-Installation.ps1
$tools = @(
    @{ Name = "Git"; Command = "git --version"; Pattern = "git version" },
    @{ Name = "Python"; Command = "python --version"; Pattern = "Python" },
    # ... more tools
)

foreach ($tool in $tools) {
    $Command = $tool.Command
    $output = Invoke-Expression $Command 2>$null  # SECURITY RISK
    if ($output -match $tool.Pattern) {
        Write-Host "✓ $($tool.Name) is installed" -ForegroundColor Green
    }
}
```

## Root Cause Analysis
1. **Legacy Pattern**: Invoke-Expression commonly used in older PowerShell scripts
2. **Convenience**: Easier than using Start-Process or native commands
3. **String Command Storage**: Commands stored as strings in hashtable
4. **Lack of Awareness**: May not be aware of security implications

## Recommended Solutions

### Solution 1: Use & (Call Operator) - Preferred
The call operator `&` is safer and more idiomatic:

```powershell
# Before
$Command = "git --version"
$output = Invoke-Expression $Command 2>$null

# After - Use call operator with split command
$CommandParts = $tool.Command -split ' ', 2
$executable = $CommandParts[0]
$arguments = if ($CommandParts.Length -gt 1) { $CommandParts[1] } else { $null }

if ($arguments) {
    $output = & $executable $arguments 2>$null
} else {
    $output = & $executable 2>$null
}
```

### Solution 2: Use Start-Process
More verbose but explicit:

```powershell
$process = Start-Process -FilePath "git" `
                         -ArgumentList "--version" `
                         -NoNewWindow `
                         -Wait `
                         -PassThru `
                         -RedirectStandardOutput "temp.txt" `
                         -RedirectStandardError "nul"

$output = Get-Content "temp.txt"
Remove-Item "temp.txt"
```

### Solution 3: Restructure to Avoid String Commands (Best)
Store commands as structured data:

```powershell
$tools = @(
    @{
        Name = "Git"
        Executable = "git"
        Arguments = "--version"
        Pattern = "git version"
    },
    @{
        Name = "Python"
        Executable = "python"
        Arguments = "--version"
        Pattern = "Python"
    },
    @{
        Name = "PostgreSQL"
        Executable = "psql"
        Arguments = "--version"
        Pattern = "psql"
    }
)

foreach ($tool in $tools) {
    try {
        $output = & $tool.Executable $tool.Arguments 2>&1
        if ($output -match $tool.Pattern) {
            Write-Information "✓ $($tool.Name) is installed"
        } else {
            Write-Warning "✗ $($tool.Name) check failed"
        }
    } catch {
        Write-Warning "✗ $($tool.Name) not found: $_"
    }
}
```

### Solution 4: Use Get-Command for Executable Checks
Even better - check if command exists first:

```powershell
function Test-CommandAvailable {
    param(
        [string]$Name,
        [string]$Executable,
        [string]$Arguments,
        [string]$Pattern
    )

    # First check if executable exists
    $cmd = Get-Command $Executable -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return $false
    }

    # Then verify with version check
    try {
        $output = & $Executable $Arguments 2>&1
        return ($output -match $Pattern)
    } catch {
        return $false
    }
}

# Usage
$tools = @(
    @{ Name = "Git"; Executable = "git"; Arguments = "--version"; Pattern = "git version" },
    @{ Name = "Python"; Executable = "python"; Arguments = "--version"; Pattern = "Python" }
)

foreach ($tool in $tools) {
    $installed = Test-CommandAvailable @tool
    if ($installed) {
        Write-Information "✓ $($tool.Name) is installed"
    } else {
        Write-Warning "✗ $($tool.Name) is not installed"
    }
}
```

## Implementation Steps

### Step 1: Refactor Verify-Installation.ps1
1. Identify all uses of Invoke-Expression
2. Restructure $tools array to store executable and arguments separately
3. Replace Invoke-Expression with call operator (&)
4. Add error handling with try-catch
5. Test with all tools in the verification list

### Step 2: Add PSScriptAnalyzer Rule
Ensure PSScriptAnalyzer catches this pattern:

```powershell
# .vscode/settings.json or PSScriptAnalyzerSettings.psd1
@{
    Rules = @{
        PSAvoidUsingInvokeExpression = @{
            Enable = $true
        }
    }
}
```

### Step 3: Add to Code Review Checklist
Update CONTRIBUTING.md:
```markdown
## PowerShell Best Practices
- ❌ **Never use Invoke-Expression** - Use `&` (call operator) or `Start-Process` instead
- ✅ Use structured command execution with proper error handling
```

### Step 4: Verify in CI/CD
Ensure PSScriptAnalyzer in CI catches this:
```yaml
# .github/workflows/sonarcloud.yml (line ~174)
- name: Run PSScriptAnalyzer (PowerShell Linter)
  shell: pwsh
  run: |
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    $results = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning
    # Should flag Invoke-Expression
```

## Acceptance Criteria
- [ ] Invoke-Expression removed from Verify-Installation.ps1
- [ ] Replaced with safe call operator (&) or Get-Command
- [ ] All tool verifications still work correctly
- [ ] Error handling improved with try-catch
- [ ] PSScriptAnalyzer rule enabled and passing
- [ ] Code review checklist updated
- [ ] No new Invoke-Expression usage introduced

## Testing Strategy
```powershell
# Test script should verify all tools correctly
Describe "Verify-Installation" {
    Context "When tool is installed" {
        It "Detects Git installation" {
            Mock Get-Command { return @{ Name = "git" } }
            Mock Invoke-CommandSafe { return "git version 2.40.0" }

            $result = Test-ToolInstalled -Name "Git" -Executable "git" -Arguments "--version"
            $result | Should -Be $true
        }
    }

    Context "When tool is not installed" {
        It "Reports tool as missing" {
            Mock Get-Command { return $null }

            $result = Test-ToolInstalled -Name "Missing" -Executable "missing"
            $result | Should -Be $false
        }
    }

    Context "Security" {
        It "Does not use Invoke-Expression" {
            $scriptContent = Get-Content "scripts/Verify-Installation.ps1" -Raw
            $scriptContent | Should -Not -Match "Invoke-Expression"
        }
    }
}
```

## Security Considerations

### Why Invoke-Expression is Dangerous
```powershell
# Example of vulnerability
$userInput = Get-UserInput  # Imagine: "; Remove-Item -Recurse C:\*"
$command = "Get-Process $userInput"
Invoke-Expression $command  # DANGEROUS! Executes: Get-Process; Remove-Item -Recurse C:\*

# Safe alternative
$output = Get-Process -Name $userInput  # Parameters are sanitized
```

### Current Risk Assessment
**Low** in this specific case because:
- Commands are hardcoded in script (not user input)
- Script is for local development environment verification
- No external input influences $Command variable

**However**, it's still bad practice and should be fixed.

## Related Issues
- Related to issue #002 (Write-Host usage) - both are style/quality issues in scripts/
- Part of broader code quality improvements
- Connected to CI/CD improvements (PSScriptAnalyzer enforcement)

## References
- [PSScriptAnalyzer Rule: PSAvoidUsingInvokeExpression](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/RuleDocumentation/AvoidUsingInvokeExpression.md)
- [PowerShell Best Practices: Avoid Invoke-Expression](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/avoid-using-invoke-expression)
- [OWASP: Code Injection](https://owasp.org/www-community/attacks/Code_Injection)

## Priority
**Medium** - Should be addressed in next maintenance cycle. While the current risk is low due to hardcoded commands, it sets a bad precedent and should be refactored to follow best practices.

## Effort Estimate
- **Refactor Verify-Installation.ps1**: 2-3 hours
- **Add PSScriptAnalyzer rule**: 30 minutes
- **Testing and validation**: 1-2 hours
- **Documentation update**: 30 minutes

**Total**: ~4-6 hours (half day)

## Notes
- This is a good teaching moment for secure PowerShell practices
- The fix also improves testability and maintainability
- Should be paired with PSScriptAnalyzer rule enforcement
- Consider creating a helper function for command verification that other scripts can reuse
