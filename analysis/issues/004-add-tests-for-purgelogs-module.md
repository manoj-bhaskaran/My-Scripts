# ISSUE-004: Add Comprehensive Tests for PurgeLogs Module

**Priority:** 🔴 CRITICAL
**Category:** Testing / Quality Assurance
**Estimated Effort:** 4 hours
**Skills Required:** PowerShell, Pester, Testing

---

## Problem Statement

The PurgeLogs module (`PurgeLogs.psm1`) handles log file retention and deletion but has **zero test coverage**. Incorrect implementation could result in deletion of important logs or failure to clean up old logs, consuming disk space.

### Current State

- **Module:** `src/powershell/modules/Utilities/PurgeLogs/PurgeLogs.psm1`
- **Test File:** Does not exist
- **Coverage:** 0%
- **Risk Level:** HIGH (can delete important files)

### Functions Without Tests

```powershell
Remove-OldLogFiles               # Deletes logs based on retention policy
Get-LogFilesToPurge             # Identifies files for deletion
Test-LogRetentionPolicy         # Validates retention configuration
Get-LogFileAge                  # Calculates file age
```

### Impact

- 🗑️ **Data Loss Risk:** Could delete important logs if retention policy is wrong
- 💾 **Disk Space Issues:** Failed purging could fill up disk
- 🐛 **Silent Failures:** Log cleanup failures may go unnoticed
- 📊 **Compliance Risk:** Incorrect retention could violate audit requirements
- 🔧 **Maintenance Burden:** No confidence in making changes

---

## Acceptance Criteria

- [ ] Create `tests/powershell/unit/PurgeLogs.Tests.ps1`
- [ ] Test log file selection based on age
- [ ] Test retention policy enforcement (days and count)
- [ ] Test file deletion with proper error handling
- [ ] Test exclusion of active/locked log files
- [ ] Test dry-run mode (list without deleting)
- [ ] Test filtering by log file pattern
- [ ] Test size-based retention (if implemented)
- [ ] Achieve >80% code coverage for PurgeLogs module
- [ ] All tests pass in CI pipeline
- [ ] Mock all file system operations

---

## Implementation Plan

### Step 1: Setup Test Infrastructure (30 minutes)

```powershell
# tests/powershell/unit/PurgeLogs.Tests.ps1
BeforeAll {
    # Import module
    $modulePath = "$PSScriptRoot/../../../src/powershell/modules/Utilities/PurgeLogs"
    Import-Module "$modulePath/PurgeLogs.psm1" -Force

    # Mock logging functions
    Mock Write-LogInfo { }
    Mock Write-LogWarning { }
    Mock Write-LogError { }
}

Describe "PurgeLogs Module" {
    # Tests go here
}

AfterAll {
    Remove-Module PurgeLogs -ErrorAction SilentlyContinue
}
```

### Step 2: Test Log File Selection (1.5 hours)

```powershell
Describe "Get-LogFilesToPurge" {
    Context "Age-based Selection" {
        It "Identifies logs older than retention days" {
            $mockLogs = @(
                @{
                    Name = "app_20251115.log"
                    FullName = "TestDrive:\logs\app_20251115.log"
                    LastWriteTime = [DateTime]::Parse("2025-11-15")  # 7 days old
                    Length = 1MB
                }
                @{
                    Name = "app_20251120.log"
                    FullName = "TestDrive:\logs\app_20251120.log"
                    LastWriteTime = [DateTime]::Parse("2025-11-20")  # 2 days old
                    Length = 1MB
                }
            )
            Mock Get-ChildItem { return $mockLogs }
            Mock Get-Date { return [DateTime]::Parse("2025-11-22") }

            $result = Get-LogFilesToPurge -LogPath "TestDrive:\logs" -RetentionDays 5

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be "app_20251115.log"
        }

        It "Returns empty array when no logs exceed retention" {
            $mockLogs = @(
                @{
                    Name = "app_20251121.log"
                    LastWriteTime = [DateTime]::Parse("2025-11-21")  # 1 day old
                }
            )
            Mock Get-ChildItem { return $mockLogs }
            Mock Get-Date { return [DateTime]::Parse("2025-11-22") }

            $result = Get-LogFilesToPurge -LogPath "TestDrive:\logs" -RetentionDays 5

            $result.Count | Should -Be 0
        }

        It "Filters by log file pattern" {
            $mockLogs = @(
                @{
                    Name = "app_20251115.log"
                    LastWriteTime = [DateTime]::Parse("2025-11-15")
                }
                @{
                    Name = "system_20251115.log"
                    LastWriteTime = [DateTime]::Parse("2025-11-15")
                }
            )
            Mock Get-ChildItem { return $mockLogs } -ParameterFilter { $Filter -eq "app_*.log" }

            $result = Get-LogFilesToPurge -LogPath "TestDrive:\logs" `
                                          -RetentionDays 5 `
                                          -FilePattern "app_*.log"

            $result.Count | Should -Be 1
            $result[0].Name | Should -Match "^app_"
        }

        It "Excludes current day's log file" {
            $mockLogs = @(
                @{
                    Name = "app_20251122.log"  # Today
                    LastWriteTime = [DateTime]::Parse("2025-11-22")
                }
                @{
                    Name = "app_20251115.log"  # Old
                    LastWriteTime = [DateTime]::Parse("2025-11-15")
                }
            )
            Mock Get-ChildItem { return $mockLogs }
            Mock Get-Date { return [DateTime]::Parse("2025-11-22") }

            $result = Get-LogFilesToPurge -LogPath "TestDrive:\logs" -RetentionDays 0

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be "app_20251115.log"
        }
    }

    Context "Count-based Selection" {
        It "Keeps only specified number of most recent files" {
            $mockLogs = @(
                @{ Name = "app_001.log"; LastWriteTime = [DateTime]::Parse("2025-11-15") }
                @{ Name = "app_002.log"; LastWriteTime = [DateTime]::Parse("2025-11-18") }
                @{ Name = "app_003.log"; LastWriteTime = [DateTime]::Parse("2025-11-20") }
                @{ Name = "app_004.log"; LastWriteTime = [DateTime]::Parse("2025-11-22") }
            )
            Mock Get-ChildItem { return $mockLogs }

            $result = Get-LogFilesToPurge -LogPath "TestDrive:\logs" -KeepCount 2

            $result.Count | Should -Be 2
            # Should mark oldest two for deletion
            $result.Name | Should -Contain "app_001.log"
            $result.Name | Should -Contain "app_002.log"
        }

        It "Returns empty when file count is below threshold" {
            $mockLogs = @(
                @{ Name = "app_001.log"; LastWriteTime = [DateTime]::Now }
            )
            Mock Get-ChildItem { return $mockLogs }

            $result = Get-LogFilesToPurge -LogPath "TestDrive:\logs" -KeepCount 5

            $result.Count | Should -Be 0
        }
    }

    Context "Size-based Selection" {
        It "Identifies logs when total size exceeds limit" {
            $mockLogs = @(
                @{
                    Name = "app_001.log"
                    LastWriteTime = [DateTime]::Parse("2025-11-15")
                    Length = 500MB
                }
                @{
                    Name = "app_002.log"
                    LastWriteTime = [DateTime]::Parse("2025-11-20")
                    Length = 600MB
                }
                @{
                    Name = "app_003.log"
                    LastWriteTime = [DateTime]::Parse("2025-11-22")
                    Length = 100MB
                }
            )
            Mock Get-ChildItem { return $mockLogs }

            # Total: 1200MB, limit: 1GB, should delete oldest until under limit
            $result = Get-LogFilesToPurge -LogPath "TestDrive:\logs" -MaxTotalSizeMB 1024

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be "app_001.log"  # Oldest
        }
    }
}
```

### Step 3: Test Log Deletion (1.5 hours)

```powershell
Describe "Remove-OldLogFiles" {
    Context "Successful Deletion" {
        BeforeEach {
            Mock Get-LogFilesToPurge {
                return @(
                    @{ FullName = "TestDrive:\logs\old1.log"; Name = "old1.log" }
                    @{ FullName = "TestDrive:\logs\old2.log"; Name = "old2.log" }
                )
            }
            Mock Remove-Item { }
            Mock Test-Path { return $true }
        }

        It "Deletes all identified log files" {
            $result = Remove-OldLogFiles -LogPath "TestDrive:\logs" -RetentionDays 30

            Assert-MockCalled Remove-Item -Times 2
            $result.FilesDeleted | Should -Be 2
        }

        It "Reports total space freed" {
            Mock Get-Item {
                return @{ Length = 10MB }
            }

            $result = Remove-OldLogFiles -LogPath "TestDrive:\logs" -RetentionDays 30

            $result.SpaceFreedMB | Should -BeGreaterThan 0
        }

        It "Logs each file deletion" {
            Mock Write-LogInfo { }

            Remove-OldLogFiles -LogPath "TestDrive:\logs" -RetentionDays 30

            Assert-MockCalled Write-LogInfo -Times 2 -ParameterFilter {
                $Message -match "Deleted.*log"
            }
        }

        It "Supports dry-run mode without deleting files" {
            Mock Remove-Item { throw "Should not delete in dry-run" }
            Mock Write-LogInfo { }

            $result = Remove-OldLogFiles -LogPath "TestDrive:\logs" -RetentionDays 30 -WhatIf

            Assert-MockCalled Remove-Item -Times 0
            $result.WouldDeleteCount | Should -Be 2
        }
    }

    Context "Error Handling" {
        It "Continues deletion if one file fails" {
            Mock Get-LogFilesToPurge {
                return @(
                    @{ FullName = "TestDrive:\logs\file1.log" }
                    @{ FullName = "TestDrive:\logs\file2.log" }
                    @{ FullName = "TestDrive:\logs\file3.log" }
                )
            }
            Mock Remove-Item { } -ParameterFilter { $_.Contains("file1") }
            Mock Remove-Item { throw "File locked" } -ParameterFilter { $_.Contains("file2") }
            Mock Remove-Item { } -ParameterFilter { $_.Contains("file3") }
            Mock Write-LogWarning { }

            $result = Remove-OldLogFiles -LogPath "TestDrive:\logs" -RetentionDays 30

            Assert-MockCalled Remove-Item -Times 3
            Assert-MockCalled Write-LogWarning -Times 1
            $result.FilesDeleted | Should -Be 2
            $result.FilesFailed | Should -Be 1
        }

        It "Skips locked/in-use files" {
            Mock Get-LogFilesToPurge {
                return @(
                    @{ FullName = "TestDrive:\logs\locked.log" }
                )
            }
            Mock Remove-Item { throw "File is locked" }
            Mock Write-LogWarning { }

            $result = Remove-OldLogFiles -LogPath "TestDrive:\logs" -RetentionDays 30

            Assert-MockCalled Write-LogWarning -ParameterFilter {
                $Message -match "locked"
            }
            $result.FilesDeleted | Should -Be 0
        }

        It "Throws error if log path doesn't exist" {
            Mock Test-Path { return $false }

            { Remove-OldLogFiles -LogPath "Z:\invalid\path" -RetentionDays 30 } |
                Should -Throw "*path does not exist*"
        }
    }

    Context "Retention Policy Validation" {
        It "Validates retention days is positive" {
            { Remove-OldLogFiles -LogPath "TestDrive:\logs" -RetentionDays -5 } |
                Should -Throw "*retention days must be positive*"
        }

        It "Validates keep count is positive" {
            { Remove-OldLogFiles -LogPath "TestDrive:\logs" -KeepCount 0 } |
                Should -Throw "*keep count must be positive*"
        }

        It "Allows combining age and count retention" {
            Mock Get-LogFilesToPurge { return @() }

            { Remove-OldLogFiles -LogPath "TestDrive:\logs" -RetentionDays 30 -KeepCount 10 } |
                Should -Not -Throw
        }
    }
}
```

### Step 4: Test Helper Functions (30 minutes)

```powershell
Describe "Get-LogFileAge" {
    It "Calculates correct age in days" {
        $fileDate = [DateTime]::Parse("2025-11-15")
        $currentDate = [DateTime]::Parse("2025-11-22")

        Mock Get-Date { return $currentDate }

        $age = Get-LogFileAge -FileDate $fileDate

        $age | Should -Be 7
    }

    It "Returns 0 for today's files" {
        $today = [DateTime]::Now.Date

        Mock Get-Date { return $today }

        $age = Get-LogFileAge -FileDate $today

        $age | Should -Be 0
    }
}

Describe "Test-LogRetentionPolicy" {
    It "Validates policy has either days or count" {
        $policy = @{
            RetentionDays = 30
        }

        Test-LogRetentionPolicy -Policy $policy | Should -Be $true
    }

    It "Rejects policy with no retention criteria" {
        $policy = @{}

        Test-LogRetentionPolicy -Policy $policy | Should -Be $false
    }

    It "Validates max size is reasonable" {
        $policy = @{
            MaxTotalSizeMB = 100000000  # 100TB - unreasonable
        }

        Test-LogRetentionPolicy -Policy $policy | Should -Be $false
    }
}
```

### Step 5: Integration with CI Pipeline (30 minutes)

Update `.github/workflows/validate-modules.yml`:

```yaml
- name: Run PurgeLogs Module Tests
  shell: pwsh
  run: |
    Install-Module -Name Pester -Force -SkipPublisherCheck

    $config = New-PesterConfiguration
    $config.Run.Path = 'tests/powershell/unit/PurgeLogs.Tests.ps1'
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = 'src/powershell/modules/Utilities/PurgeLogs/*.psm1'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = 'test-results/PurgeLogs.xml'

    $result = Invoke-Pester -Configuration $config

    if ($result.FailedCount -gt 0) {
        throw "PurgeLogs tests failed"
    }

    if ($result.CodeCoverage.CoveragePercent -lt 80) {
        Write-Warning "Coverage is $($result.CodeCoverage.CoveragePercent)%, below 80% threshold"
    }
```

---

## Testing Strategy

### Unit Tests (Primary Focus)
- **File Selection:** Test age, count, and size-based selection
- **Deletion:** Test actual deletion with mocked file system
- **Dry-run:** Test WhatIf parameter works correctly
- **Error Handling:** Test locked files, missing paths, permission errors
- **Validation:** Test retention policy validation

### Integration Tests (Future)
- Create actual log files in test directory
- Run purge operation
- Verify correct files deleted
- Verify retention policy enforced

### Manual Testing Checklist
1. Test with real log files (create test set)
2. Verify dry-run shows correct files
3. Verify actual deletion works
4. Test with locked files
5. Verify space calculation is accurate

---

## Related Issues

- ISSUE-002: Add Tests for PostgresBackup Module
- ISSUE-003: Add Tests for Git Hooks
- ISSUE-010: Add Tests for FileOperations Module

---

## References

- Pester Documentation: https://pester.dev/docs/quick-start
- PowerShell WhatIf Support: https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess
- Log Rotation Best Practices: https://www.loggly.com/ultimate-guide/managing-log-files/

---

## Success Metrics

- [ ] All PurgeLogs tests passing in CI
- [ ] >80% code coverage for PurgeLogs module
- [ ] Zero failures across Windows/Linux platforms
- [ ] All file selection scenarios tested
- [ ] All retention policies tested
- [ ] Error handling verified
- [ ] Dry-run mode verified

---

**Estimated Time Breakdown:**
- Test infrastructure setup: 0.5 hours
- File selection tests: 1.5 hours
- Deletion tests: 1.5 hours
- Helper function tests: 0.5 hours
- CI integration: 0.5 hours
- **Total: 4 hours**
