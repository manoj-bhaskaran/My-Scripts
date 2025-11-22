# ISSUE-003: Add Comprehensive Tests for Git Hooks

**Priority:** 🔴 CRITICAL
**Category:** Testing / Quality Assurance / Automation
**Estimated Effort:** 6 hours
**Skills Required:** PowerShell, Pester, Git, Testing

---

## Problem Statement

Git hook scripts (`Invoke-PostCommitHook.ps1` and `Invoke-PostMergeHook.ps1`) are critical for automated module deployment but have **zero test coverage**. These scripts run automatically during development workflow and deployment failures could corrupt the development environment.

### Current State

- **Files:**
  - `src/powershell/git/Invoke-PostCommitHook.ps1`
  - `src/powershell/git/Invoke-PostMergeHook.ps1`
- **Test Files:** Do not exist
- **Coverage:** 0%
- **Risk Level:** CRITICAL (affects development automation)

### Functions Without Tests

```powershell
# Post-commit hook
Invoke-PostCommitHook           # Main hook orchestrator
Deploy-ModulesToPath            # Module deployment
Sync-FilesToMirror             # File synchronization
Read-DeploymentConfig          # Config parsing

# Post-merge hook
Invoke-PostMergeHook           # Main hook orchestrator
Update-Dependencies            # Dependency management
```

### Impact

- 🔧 **Deployment Failures:** Module deployment may fail silently
- 📦 **Corrupted Installations:** Bad deployments could break development environment
- 🔄 **Synchronization Issues:** File sync could corrupt staging mirror
- 🐛 **Regression Risk:** Changes to hooks could break workflow
- ❌ **No Verification:** No way to test hooks before committing changes

---

## Acceptance Criteria

- [ ] Create `tests/powershell/unit/Invoke-PostCommitHook.Tests.ps1`
- [ ] Create `tests/powershell/unit/Invoke-PostMergeHook.Tests.ps1`
- [ ] Test configuration file reading and validation
- [ ] Test module deployment with valid config
- [ ] Test file synchronization logic
- [ ] Test error handling when config is missing
- [ ] Test error handling when deployment path is invalid
- [ ] Test selective module deployment (only changed modules)
- [ ] Test logging of all operations
- [ ] Achieve >75% code coverage for git hook scripts
- [ ] All tests pass in CI pipeline
- [ ] Mock all file system and git operations

---

## Implementation Plan

### Step 1: Setup Test Infrastructure (1 hour)

```powershell
# tests/powershell/unit/Invoke-PostCommitHook.Tests.ps1
BeforeAll {
    # Import script (dot source since it's not a module)
    . "$PSScriptRoot/../../../src/powershell/git/Invoke-PostCommitHook.ps1"

    # Mock external dependencies
    Mock Write-LogInfo { }
    Mock Write-LogWarning { }
    Mock Write-LogError { }
    Mock Get-GitRoot { return "TestDrive:\repo" }
}

Describe "Post-Commit Hook" {
    # Tests go here
}
```

### Step 2: Test Configuration Reading (1.5 hours)

```powershell
Describe "Read-DeploymentConfig" {
    Context "Valid Configuration" {
        It "Reads configuration from JSON file" {
            $configJson = @{
                enabled = $true
                stagingMirror = "C:\Users\test\Scripts"
            } | ConvertTo-Json

            Mock Get-Content { return $configJson }
            Mock Test-Path { return $true }

            $result = Read-DeploymentConfig -ConfigPath "TestDrive:\config.json"

            $result.enabled | Should -Be $true
            $result.stagingMirror | Should -Be "C:\Users\test\Scripts"
        }

        It "Returns null when config file doesn't exist" {
            Mock Test-Path { return $false }

            $result = Read-DeploymentConfig -ConfigPath "TestDrive:\missing.json"

            $result | Should -BeNullOrEmpty
        }

        It "Handles config with deployment disabled" {
            $configJson = @{
                enabled = $false
                stagingMirror = "C:\Users\test\Scripts"
            } | ConvertTo-Json

            Mock Get-Content { return $configJson }
            Mock Test-Path { return $true }

            $result = Read-DeploymentConfig -ConfigPath "TestDrive:\config.json"

            $result.enabled | Should -Be $false
        }

        It "Validates staging mirror path exists" {
            $configJson = @{
                enabled = $true
                stagingMirror = "C:\Users\test\Scripts"
            } | ConvertTo-Json

            Mock Get-Content { return $configJson }
            Mock Test-Path { return $true } -ParameterFilter { $Path -match "config.json" }
            Mock Test-Path { return $false } -ParameterFilter { $Path -match "Scripts" }
            Mock Write-LogWarning { }

            $result = Read-DeploymentConfig -ConfigPath "TestDrive:\config.json" -ValidatePaths

            Assert-MockCalled Write-LogWarning -ParameterFilter {
                $Message -match "staging mirror.*not exist"
            }
        }
    }

    Context "Invalid Configuration" {
        It "Handles malformed JSON gracefully" {
            Mock Get-Content { return "{ invalid json" }
            Mock Test-Path { return $true }
            Mock Write-LogError { }

            $result = Read-DeploymentConfig -ConfigPath "TestDrive:\config.json"

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-LogError
        }

        It "Handles missing required fields" {
            $configJson = @{
                enabled = $true
                # Missing stagingMirror
            } | ConvertTo-Json

            Mock Get-Content { return $configJson }
            Mock Test-Path { return $true }
            Mock Write-LogWarning { }

            $result = Read-DeploymentConfig -ConfigPath "TestDrive:\config.json"

            Assert-MockCalled Write-LogWarning -ParameterFilter {
                $Message -match "missing.*stagingMirror"
            }
        }
    }
}
```

### Step 3: Test Module Deployment (2 hours)

```powershell
Describe "Deploy-ModulesToPath" {
    Context "Successful Deployment" {
        BeforeEach {
            # Setup mock module structure
            Mock Test-Path { return $true }
            Mock Get-ChildItem {
                return @(
                    @{ Name = "ErrorHandling"; FullName = "TestDrive:\src\modules\Core\ErrorHandling"; PSIsContainer = $true }
                    @{ Name = "FileOperations"; FullName = "TestDrive:\src\modules\Core\FileOperations"; PSIsContainer = $true }
                )
            }
            Mock Copy-Item { }
            Mock New-Item { }
        }

        It "Deploys modules to PSModulePath" {
            $targetPath = "TestDrive:\PSModules"

            Deploy-ModulesToPath -ModulePath "TestDrive:\src\modules" -TargetPath $targetPath

            Assert-MockCalled Copy-Item -Times 2  # Two modules
        }

        It "Creates target directory if it doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -match "PSModules" }
            Mock New-Item { return @{ FullName = "TestDrive:\PSModules" } }

            Deploy-ModulesToPath -ModulePath "TestDrive:\src\modules" -TargetPath "TestDrive:\PSModules"

            Assert-MockCalled New-Item -Times 1 -ParameterFilter { $ItemType -eq "Directory" }
        }

        It "Preserves module directory structure" {
            Deploy-ModulesToPath -ModulePath "TestDrive:\src\modules" -TargetPath "TestDrive:\PSModules"

            Assert-MockCalled Copy-Item -ParameterFilter {
                $Recurse -eq $true -and $Force -eq $true
            }
        }

        It "Logs each module deployment" {
            Mock Write-LogInfo { }

            Deploy-ModulesToPath -ModulePath "TestDrive:\src\modules" -TargetPath "TestDrive:\PSModules"

            Assert-MockCalled Write-LogInfo -Times 2 -ParameterFilter {
                $Message -match "Deployed.*module"
            }
        }

        It "Deploys only specified modules when ModuleFilter provided" {
            Mock Get-ChildItem {
                return @(
                    @{ Name = "ErrorHandling"; FullName = "TestDrive:\src\modules\ErrorHandling"; PSIsContainer = $true }
                )
            } -ParameterFilter { $Filter -eq "ErrorHandling" }

            Deploy-ModulesToPath -ModulePath "TestDrive:\src\modules" `
                                -TargetPath "TestDrive:\PSModules" `
                                -ModuleFilter @("ErrorHandling")

            Assert-MockCalled Copy-Item -Times 1
        }
    }

    Context "Error Handling" {
        It "Handles access denied errors gracefully" {
            Mock Get-ChildItem { return @(@{ Name = "TestModule"; FullName = "TestDrive:\modules\TestModule" }) }
            Mock Copy-Item { throw "Access denied" }
            Mock Write-LogError { }

            { Deploy-ModulesToPath -ModulePath "TestDrive:\src\modules" -TargetPath "C:\Windows\System32" } |
                Should -Not -Throw

            Assert-MockCalled Write-LogError -ParameterFilter {
                $Message -match "Access denied"
            }
        }

        It "Continues deployment if one module fails" {
            Mock Get-ChildItem {
                return @(
                    @{ Name = "Module1"; FullName = "TestDrive:\modules\Module1" }
                    @{ Name = "Module2"; FullName = "TestDrive:\modules\Module2" }
                )
            }
            Mock Copy-Item { } -ParameterFilter { $_.Name -eq "Module1" }
            Mock Copy-Item { throw "Error" } -ParameterFilter { $_.Name -eq "Module2" }
            Mock Write-LogError { }

            Deploy-ModulesToPath -ModulePath "TestDrive:\src\modules" -TargetPath "TestDrive:\PSModules"

            Assert-MockCalled Copy-Item -Times 2
            Assert-MockCalled Write-LogError -Times 1
        }
    }
}
```

### Step 4: Test File Synchronization (1.5 hours)

```powershell
Describe "Sync-FilesToMirror" {
    Context "Successful Synchronization" {
        It "Syncs all files to staging mirror" {
            Mock Get-ChildItem {
                return @(
                    @{ FullName = "TestDrive:\repo\script1.ps1"; PSIsContainer = $false }
                    @{ FullName = "TestDrive:\repo\script2.ps1"; PSIsContainer = $false }
                )
            }
            Mock Copy-Item { }
            Mock Test-Path { return $true }

            Sync-FilesToMirror -SourcePath "TestDrive:\repo" -MirrorPath "TestDrive:\mirror"

            Assert-MockCalled Copy-Item -Times 2
        }

        It "Preserves directory structure" {
            Mock Get-ChildItem {
                return @(
                    @{ FullName = "TestDrive:\repo\src\script.ps1"; PSIsContainer = $false }
                )
            }
            Mock Copy-Item { }

            Sync-FilesToMirror -SourcePath "TestDrive:\repo" -MirrorPath "TestDrive:\mirror"

            Assert-MockCalled Copy-Item -ParameterFilter {
                $Destination -match "mirror.*src"
            }
        }

        It "Excludes .git directory" {
            Mock Get-ChildItem {
                return @(
                    @{ FullName = "TestDrive:\repo\script.ps1"; PSIsContainer = $false }
                )
            } -ParameterFilter { $Exclude -contains ".git" }

            Sync-FilesToMirror -SourcePath "TestDrive:\repo" -MirrorPath "TestDrive:\mirror"

            Assert-MockCalled Get-ChildItem -ParameterFilter { $Exclude -contains ".git" }
        }

        It "Excludes files from .gitignore" {
            Mock Get-Content {
                return @("logs/", "*.log", "__pycache__/")
            } -ParameterFilter { $Path -match ".gitignore" }

            Mock Get-ChildItem {
                return @()  # All files filtered by exclusions
            }

            Sync-FilesToMirror -SourcePath "TestDrive:\repo" -MirrorPath "TestDrive:\mirror"

            Assert-MockCalled Get-ChildItem -ParameterFilter {
                $Exclude -contains "logs" -and $Exclude -contains "*.log"
            }
        }
    }

    Context "Incremental Sync" {
        It "Only copies modified files when using -Incremental" {
            Mock Get-ChildItem {
                return @(
                    @{
                        FullName = "TestDrive:\repo\script.ps1"
                        LastWriteTime = [DateTime]::Parse("2025-11-22 10:00:00")
                    }
                )
            }
            Mock Get-Item {
                return @{ LastWriteTime = [DateTime]::Parse("2025-11-22 09:00:00") }
            } -ParameterFilter { $Path -match "mirror" }
            Mock Copy-Item { }

            Sync-FilesToMirror -SourcePath "TestDrive:\repo" -MirrorPath "TestDrive:\mirror" -Incremental

            Assert-MockCalled Copy-Item -Times 1  # File is newer, should copy
        }

        It "Skips unchanged files when using -Incremental" {
            Mock Get-ChildItem {
                return @(
                    @{
                        FullName = "TestDrive:\repo\script.ps1"
                        LastWriteTime = [DateTime]::Parse("2025-11-22 09:00:00")
                    }
                )
            }
            Mock Get-Item {
                return @{ LastWriteTime = [DateTime]::Parse("2025-11-22 10:00:00") }
            } -ParameterFilter { $Path -match "mirror" }
            Mock Copy-Item { }

            Sync-FilesToMirror -SourcePath "TestDrive:\repo" -MirrorPath "TestDrive:\mirror" -Incremental

            Assert-MockCalled Copy-Item -Times 0  # File is older, skip
        }
    }
}
```

### Step 5: Test Post-Merge Hook (1 hour)

```powershell
# tests/powershell/unit/Invoke-PostMergeHook.Tests.ps1
Describe "Invoke-PostMergeHook" {
    Context "Hook Execution" {
        It "Runs successfully with valid configuration" {
            Mock Read-DeploymentConfig {
                return @{ enabled = $true; stagingMirror = "TestDrive:\mirror" }
            }
            Mock Update-Dependencies { }
            Mock Write-LogInfo { }

            { Invoke-PostMergeHook } | Should -Not -Throw

            Assert-MockCalled Update-Dependencies -Times 1
        }

        It "Skips execution when deployment is disabled" {
            Mock Read-DeploymentConfig {
                return @{ enabled = $false }
            }
            Mock Update-Dependencies { }
            Mock Write-LogInfo { }

            Invoke-PostMergeHook

            Assert-MockCalled Update-Dependencies -Times 0
        }

        It "Updates Python dependencies if requirements.txt changed" {
            Mock Get-GitDiff { return @("requirements.txt") }
            Mock Invoke-Expression { }

            Invoke-PostMergeHook

            Assert-MockCalled Invoke-Expression -ParameterFilter {
                $Command -match "pip install.*requirements.txt"
            }
        }

        It "Reinstalls PowerShell modules if module files changed" {
            Mock Get-GitDiff { return @("src/powershell/modules/ErrorHandling/ErrorHandling.psm1") }
            Mock Deploy-ModulesToPath { }

            Invoke-PostMergeHook

            Assert-MockCalled Deploy-ModulesToPath -Times 1
        }
    }
}
```

---

## Testing Strategy

### Unit Tests (Primary Focus)
- **Configuration:** Mock file reading, test JSON parsing
- **Module Deployment:** Mock file copying, test logic
- **File Sync:** Mock file operations, test filtering
- **Error Handling:** Test all failure scenarios
- **Integration:** Test hooks call correct functions

### Integration Tests (Future - ISSUE-022)
- Create test git repository
- Trigger actual hooks
- Verify modules deployed correctly
- Verify files synchronized

### Manual Testing Checklist
1. Run tests on Windows and Linux
2. Verify coverage report shows >75%
3. Test actual git commit (manual)
4. Verify modules deployed after commit
5. Check staging mirror synchronized

---

## Related Issues

- ISSUE-002: Add Tests for PostgresBackup Module
- ISSUE-004: Add Tests for PurgeLogs Module
- ISSUE-022: Add Git Hooks Integration Tests

---

## References

- Pester Documentation: https://pester.dev/docs/quick-start
- Git Hooks Documentation: https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks
- PowerShell Module Deployment: https://docs.microsoft.com/en-us/powershell/scripting/developer/module/installing-a-powershell-module

---

## Success Metrics

- [ ] All git hook tests passing in CI
- [ ] >75% code coverage for both hook scripts
- [ ] Zero failures across Windows/Linux platforms
- [ ] Configuration reading fully tested
- [ ] Module deployment logic fully tested
- [ ] File synchronization logic fully tested
- [ ] Error handling verified for all failure modes

---

**Estimated Time Breakdown:**
- Test infrastructure setup: 1 hour
- Configuration reading tests: 1.5 hours
- Module deployment tests: 2 hours
- File synchronization tests: 1.5 hours
- Post-merge hook tests: 1 hour
- **Total: 6 hours**
