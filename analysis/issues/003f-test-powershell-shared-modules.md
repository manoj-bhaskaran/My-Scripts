# Issue #003f: Test Shared PowerShell Modules

**Parent Issue**: [#003: Low Test Coverage](./003-low-test-coverage.md)
**Phase**: Phase 2 - Core Modules
**Effort**: 8 hours

## Description
Add comprehensive tests for shared PowerShell modules. These are used across multiple scripts and need thorough testing.

## Scope
- `PowerShellLoggingFramework` - Cross-platform logging
- `ErrorHandling` - Standardized error handling
- `FileOperations` - File operations with resilience
- `ProgressReporter` - Progress tracking

## Implementation

### Logging Framework Tests
```powershell
# tests/powershell/unit/PowerShellLoggingFramework.Tests.ps1

Describe "PowerShellLoggingFramework" {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../src/powershell/modules/Core/Logging/PowerShellLoggingFramework" -Force
    }

    Context "Logger Initialization" {
        It "Creates logger with default settings" {
            $logger = Initialize-Logger -Name "TestLogger"
            $logger | Should -Not -BeNullOrEmpty
            $logger.Name | Should -Be "TestLogger"
        }

        It "Uses custom log directory" {
            $customDir = "TestDrive:/CustomLogs"
            $logger = Initialize-Logger -Name "Test" -LogDirectory $customDir
            Test-Path $customDir | Should -Be $true
        }
    }

    Context "Logging Operations" {
        It "Writes structured log messages" {
            $logFile = "TestDrive:/test.log"
            Write-StructuredLog -Level "Info" -Message "Test" -LogFile $logFile

            $content = Get-Content $logFile -Raw
            $content | Should -Match "Info"
            $content | Should -Match "Test"
        }

        It "Includes metadata in logs" {
            $metadata = @{ UserId = 123; Action = "Delete" }
            Write-StructuredLog -Level "Info" -Message "Action" -Metadata $metadata -LogFile "TestDrive:/test.log"

            $content = Get-Content "TestDrive:/test.log" -Raw
            $content | Should -Match "UserId"
            $content | Should -Match "123"
        }
    }
}
```

### Error Handling Tests
```powershell
# tests/powershell/unit/ErrorHandling.Tests.ps1 (expand)

Describe "Retry Logic" {
    It "Retries failed operations" {
        $script:attemptCount = 0

        $result = Invoke-WithRetry -ScriptBlock {
            $script:attemptCount++
            if ($script:attemptCount -lt 3) {
                throw "Fail"
            }
            return "Success"
        } -MaxRetries 5 -Delay 0.1

        $result | Should -Be "Success"
        $script:attemptCount | Should -Be 3
    }

    It "Respects max retry limit" {
        $result = Invoke-WithRetry -ScriptBlock {
            throw "Always fails"
        } -MaxRetries 3 -Delay 0.1 -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
    }
}
```

## Acceptance Criteria
- [ ] PowerShellLoggingFramework has 50%+ coverage
- [ ] ErrorHandling has 60%+ coverage
- [ ] FileOperations has 50%+ coverage
- [ ] ProgressReporter has 40%+ coverage
- [ ] All public functions tested
- [ ] Integration between modules tested

## Benefits
- Validates shared infrastructure
- Prevents widespread failures
- Documents module APIs
- Enables safe refactoring

## Effort
8 hours

## Related
- Issue #003e (Python shared modules)
- Issue #001 (empty catch blocks in modules)
