# Testing PowerShell Linting Hook

## Prerequisites

1. PowerShell 7+ installed (`pwsh`)
2. PSScriptAnalyzer module installed:
   ```powershell
   Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
   ```
3. Pre-commit framework installed:
   ```bash
   pip install pre-commit
   pre-commit install
   ```

## Test Case 1: Valid PowerShell File

Create a valid PowerShell file:

```powershell
# test-valid.ps1
function Test-ValidFunction {
    param(
        [string]$Name
    )
    Write-Output "Hello, $Name"
}
```

Expected result: Hook should pass ✅

```bash
git add test-valid.ps1
git commit -m "test: add valid PowerShell file"
# Should succeed
```

## Test Case 2: PowerShell File with Errors

Create a PowerShell file with PSScriptAnalyzer errors:

```powershell
# test-invalid.ps1
function Test-InvalidFunction {
    # Using Invoke-Expression is a security risk
    Invoke-Expression "Write-Output 'This is dangerous'"
}
```

Expected result: Hook should fail ❌

```bash
git add test-invalid.ps1
git commit -m "test: add invalid PowerShell file"
# Should fail with PSScriptAnalyzer error
```

## Test Case 3: Multiple Files

Create multiple PowerShell files:

```bash
# One valid, one invalid
echo 'Write-Output "Valid"' > test-1.ps1
echo 'Invoke-Expression "Bad"' > test-2.ps1

git add test-1.ps1 test-2.ps1
git commit -m "test: add multiple files"
# Should fail due to test-2.ps1
```

## Test Case 4: Skip Hook

Test bypassing the hook:

```bash
SKIP=psscriptanalyzer git commit -m "test: skip linting"
# Should succeed even with errors
```

## Test Case 5: Manual Hook Run

Test running the hook manually:

```bash
# Run on all files
pre-commit run psscriptanalyzer --all-files

# Run on specific file
pre-commit run psscriptanalyzer --files src/powershell/example.ps1
```

## Expected Behavior

1. Hook should run on `.ps1`, `.psm1`, and `.psd1` files
2. Hook should use settings from `config/PSScriptAnalyzerSettings.psd1`
3. Hook should only report errors (Severity: Error)
4. Hook should display violations in a readable format
5. Hook should exit with code 1 if any errors found
6. Hook should exit with code 0 if no errors found

## Verification

After testing, verify:

- [ ] Hook runs on PowerShell files
- [ ] Hook uses correct settings file
- [ ] Hook catches PSScriptAnalyzer errors
- [ ] Hook allows valid code to pass
- [ ] Hook can be skipped with `SKIP=psscriptanalyzer`
- [ ] Hook integrates with `git commit` workflow
