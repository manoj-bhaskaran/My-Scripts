# Issue #008: Large and Complex PowerShell Scripts Need Refactoring

## Severity
**Medium** - Impacts maintainability and testability

## Category
Technical Debt / Code Quality / Refactoring

## Description
Several PowerShell scripts have grown significantly large and complex, making them difficult to:
- Understand and maintain
- Test thoroughly
- Refactor safely
- Review in pull requests
- Debug when issues occur

Three scripts stand out as particularly problematic:

## Problem Scripts

### 1. FileDistributor.ps1 - **2,747 lines** (134 KB)
**Location**: `src/powershell/file-management/FileDistributor.ps1`

**Issues**:
- Nearly 3,000 lines in a single file
- Multiple responsibilities mixed together
- Difficult to test individual functions
- Complex state management
- 33 empty catch blocks (see Issue #001)
- High cognitive complexity

**Functionality** (from content analysis):
- File distribution logic
- Queue management
- Retry mechanisms
- Directory creation
- File movement
- Stream handling
- Randomization logic
- Progress tracking

**Should be split into**:
- `FileDistributor.Core.psm1` - Core distribution logic
- `FileDistributor.Queue.psm1` - Queue management
- `FileDistributor.Retry.psm1` - Retry logic
- `FileDistributor.FileSystem.psm1` - File operations
- `Invoke-FileDistribution.ps1` - Main entry point script

### 2. Expand-ZipsAndClean.ps1 - **758 lines** (32 KB)
**Location**: `src/powershell/file-management/Expand-ZipsAndClean.ps1`

**Issues**:
- Multiple concerns: ZIP expansion, file cleanup, validation
- Complex control flow
- Hard to unit test
- Mixed abstraction levels

**Functionality**:
- ZIP file extraction
- File validation
- Cleanup operations
- Progress reporting
- Error handling

**Should be split into**:
- `Expand-Zip.ps1` - ZIP extraction only
- `Invoke-FileCleanup.ps1` - Cleanup operations
- Share common functions via module

### 3. Copy-AndroidFiles.ps1 - **~800 lines** (38 KB)
**Location**: `src/powershell/file-management/Copy-AndroidFiles.ps1`

**Issues**:
- Android-specific file operations
- ADB integration
- TAR handling
- Multiple operation modes

**Should consider**:
- Extracting ADB operations to module
- Separating TAR operations
- Creating reusable Android file utilities

## Impact

### Maintainability Issues
- **Cognitive Load**: Takes significant time to understand full script
- **Change Risk**: Modifications in one area can break unrelated functionality
- **Code Review**: PRs touching these files are difficult to review
- **Onboarding**: New contributors struggle with complexity

### Testing Challenges
- **Unit Testing**: Hard to test individual functions in isolation
- **Coverage**: Low test coverage due to complexity (0.37% overall)
- **Mocking**: Difficult to mock dependencies in monolithic scripts
- **Integration Testing**: Hard to test specific scenarios

### Debugging Difficulty
- **Stack Traces**: Hard to identify exact failure location
- **State Tracking**: Complex state makes debugging challenging
- **Logging**: Difficult to add appropriate logging at right granularity

### Performance Concerns
- **Load Time**: Large scripts slow to parse and load
- **Memory**: Entire script loaded into memory even for simple operations
- **Code Reuse**: Difficult to reuse parts of functionality

## Complexity Metrics

### FileDistributor.ps1
```
Lines: 2,747
Size: 134 KB
Functions: ~20+ (estimated)
Empty Catch Blocks: 13
Cyclomatic Complexity: Very High (estimated 50+)
Cognitive Complexity: Very High
```

### Recommended Thresholds
- **Maximum script size**: 500 lines
- **Maximum function size**: 50 lines
- **Maximum cyclomatic complexity**: 15
- **Maximum cognitive complexity**: 20

## Root Cause Analysis

### Why Scripts Grew Large
1. **Feature Creep**: Added features without refactoring
2. **Deadline Pressure**: Faster to add to existing file than refactor
3. **No Size Limits**: No automated checks for file size
4. **Lack of Modules**: Not enough shared module infrastructure
5. **Single File Convenience**: Easier to maintain one file than multiple

### Historical Context
From repository history, these scripts likely started small and grew over time as requirements evolved. This is natural but requires periodic refactoring.

## Recommended Solution

### Phase 1: Extract Common Modules (Priority: HIGH)

#### Create FileSystem Module
Extract file operations used across multiple scripts:

```powershell
# src/powershell/modules/Core/FileSystem/Public/New-DirectoryIfMissing.ps1
function New-DirectoryIfMissing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# src/powershell/modules/Core/FileSystem/Public/Test-FileInUse.ps1
# src/powershell/modules/Core/FileSystem/Public/Move-FileWithRetry.ps1
# src/powershell/modules/Core/FileSystem/Public/Get-FileMd5Hash.ps1
```

#### Create Queue Module
Extract queue management logic:

```powershell
# src/powershell/modules/Utilities/Queue/Public/New-FileQueue.ps1
# src/powershell/modules/Utilities/Queue/Public/Add-FileToQueue.ps1
# src/powershell/modules/Utilities/Queue/Public/Get-NextQueuedFile.ps1
```

### Phase 2: Refactor FileDistributor.ps1 (Priority: HIGH)

**Step 1: Create Module Structure**
```
src/powershell/modules/FileManagement/
└── FileDistributor/
    ├── FileDistributor.psd1
    ├── FileDistributor.psm1
    ├── Public/
    │   ├── Invoke-FileDistribution.ps1
    │   ├── Start-FileQueue.ps1
    │   └── Get-DistributionStatus.ps1
    └── Private/
        ├── Queue/
        │   ├── Initialize-Queue.ps1
        │   ├── Process-QueueItem.ps1
        │   └── Update-QueueState.ps1
        ├── FileOperations/
        │   ├── Move-QueuedFile.ps1
        │   ├── Test-FileAccessibility.ps1
        │   └── Resolve-FileConflict.ps1
        └── Retry/
            ├── Invoke-WithRetry.ps1
            └── Get-RetryDelay.ps1
```

**Step 2: Extract Functions Incrementally**
```powershell
# Don't refactor everything at once!
# Extract one subsystem at a time:

# Week 1: Extract file operations
# Week 2: Extract queue management
# Week 3: Extract retry logic
# Week 4: Extract main distribution logic
# Week 5: Remove old monolithic script
```

**Step 3: Maintain Backwards Compatibility**
```powershell
# FileDistributor.ps1 (legacy wrapper)
<#
.SYNOPSIS
    DEPRECATED: Use FileDistributor module instead.
    This script is maintained for backwards compatibility only.

.DESCRIPTION
    This script imports the FileDistributor module and calls it.
    Please update your scripts to use:
        Import-Module FileDistributor
        Invoke-FileDistribution -Source $src -Target $tgt

.NOTES
    Deprecated: 2025-12-04
    Remove After: 2026-03-04 (3 months deprecation period)
#>

[CmdletBinding()]
param($Source, $Target, $Options)

Write-Warning "FileDistributor.ps1 is deprecated. Use FileDistributor module instead."
Import-Module "$PSScriptRoot/../modules/FileManagement/FileDistributor" -Force

Invoke-FileDistribution -Source $Source -Target $Target @Options
```

### Phase 3: Refactor Expand-ZipsAndClean.ps1 (Priority: MEDIUM)

**Simpler Split**:
```powershell
# src/powershell/file-management/Expand-Zip.ps1 (~200 lines)
# Extract ZIP expansion logic only

# src/powershell/file-management/Clean-ExtractedFiles.ps1 (~150 lines)
# Extract cleanup logic

# src/powershell/modules/Core/Archive/
# Create Archive module for reusable ZIP operations
```

### Phase 4: Refactor Copy-AndroidFiles.ps1 (Priority: LOW)

**Extract Android Utilities**:
```powershell
# src/powershell/modules/Utilities/Android/
# Create Android module for ADB and device operations

# Keep Copy-AndroidFiles.ps1 as thin orchestration script
```

## Implementation Strategy

### Incremental Approach (Recommended)
1. **Don't rewrite from scratch** - high risk, low value
2. **Extract one function at a time** - safe, testable
3. **Add tests as you extract** - improve coverage incrementally
4. **Maintain backwards compatibility** - don't break existing users
5. **Deprecate gradually** - 3-month warning period

### Testing Strategy
```powershell
# For each extracted function, add tests BEFORE extraction

Describe "Move-QueuedFile" {
    Context "When file is accessible" {
        It "Moves file successfully" {
            # Arrange
            $source = "TestDrive:/source/file.txt"
            $dest = "TestDrive:/dest/file.txt"
            New-Item -Path $source -ItemType File -Force

            # Act
            Move-QueuedFile -Source $source -Destination $dest

            # Assert
            Test-Path $dest | Should -Be $true
            Test-Path $source | Should -Be $false
        }
    }

    Context "When file is in use" {
        It "Retries with backoff" {
            # Test retry logic
        }
    }
}
```

### Code Review Checklist
- [ ] Each new module is under 500 lines
- [ ] Each function is under 50 lines
- [ ] Cyclomatic complexity under 15
- [ ] Unit tests added for extracted functions
- [ ] Integration tests still pass
- [ ] Documentation updated
- [ ] Backwards compatibility maintained

## Acceptance Criteria

### Phase 1 (Month 1)
- [ ] FileSystem module created with common functions
- [ ] Queue module created with queue operations
- [ ] Functions extracted and tested
- [ ] Other scripts updated to use new modules

### Phase 2 (Month 2-3)
- [ ] FileDistributor.ps1 reduced to under 500 lines
- [ ] Core logic extracted to FileDistributor module
- [ ] Test coverage for module reaches 30%+
- [ ] Original script maintained as backwards-compatible wrapper
- [ ] Documentation updated

### Phase 3 (Month 4)
- [ ] Expand-ZipsAndClean.ps1 split into separate scripts
- [ ] Archive module created for shared ZIP operations
- [ ] Test coverage for new scripts reaches 40%+

### Phase 4 (Month 5-6)
- [ ] Copy-AndroidFiles.ps1 refactored
- [ ] Android module created
- [ ] All file-management scripts under 500 lines

### Ongoing
- [ ] PSScriptAnalyzer rule for maximum file size
- [ ] Code review process includes size checks
- [ ] No script exceeds 500 lines without justification

## Benefits

### Immediate Benefits
- **Testability**: Smaller functions easier to test
- **Reusability**: Extracted modules used across scripts
- **Maintainability**: Easier to understand and modify
- **Code Review**: Smaller changes easier to review

### Long-term Benefits
- **Onboarding**: New developers can understand modules incrementally
- **Reliability**: Better test coverage catches bugs earlier
- **Performance**: Can load only needed modules
- **Evolution**: Easier to add features without increasing complexity

## Monitoring

### Automated Checks
```powershell
# Add to pre-commit hook or CI
$maxLines = 500
$largeFiles = Get-ChildItem -Path src -Recurse -Filter *.ps1 |
    Where-Object { (Get-Content $_.FullName).Count -gt $maxLines } |
    Select-Object FullName, @{N='Lines';E={(Get-Content $_.FullName).Count}}

if ($largeFiles) {
    Write-Warning "Large files detected:"
    $largeFiles | Format-Table
    # Don't fail, just warn (for now)
}
```

### Complexity Analysis
```powershell
# Use PSScriptAnalyzer for complexity metrics
Invoke-ScriptAnalyzer -Path . -Recurse -IncludeRule PSAvoidLongFunctions
```

## Effort Estimate

### Phase 1 (Common Modules)
- Extract FileSystem module: 16-24 hours
- Extract Queue module: 8-16 hours
- Add tests: 16-24 hours
**Subtotal**: ~40-64 hours (1-1.5 weeks)

### Phase 2 (FileDistributor)
- Design module structure: 8 hours
- Extract file operations: 16-24 hours
- Extract queue logic: 16-24 hours
- Extract retry logic: 8-16 hours
- Testing: 24-32 hours
- Documentation: 8 hours
**Subtotal**: ~80-112 hours (2-3 weeks)

### Phase 3 (Expand-ZipsAndClean)
- Split script: 16-24 hours
- Create Archive module: 16-24 hours
- Testing: 16-24 hours
**Subtotal**: ~48-72 hours (1-1.5 weeks)

### Phase 4 (Copy-AndroidFiles)
- Extract Android module: 16-24 hours
- Refactor script: 16-24 hours
- Testing: 16-24 hours
**Subtotal**: ~48-72 hours (1-1.5 weeks)

**Total**: ~216-320 hours (5-8 weeks)

## Priority
**Medium** - Should be addressed over next 6 months. While not blocking immediate work, technical debt accumulates interest. Start with Phase 1 (common modules) as it provides immediate value.

## Related Issues
- Issue #001: Empty catch blocks (many in FileDistributor.ps1)
- Issue #003: Low test coverage (complexity hinders testing)
- Issue #009: Module organization improvements

## References
- [PowerShell Best Practices: Script Size](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- [Code Complete: Managing Complexity](https://www.amazon.com/Code-Complete-Practical-Handbook-Construction/dp/0735619670)
- [Refactoring: Improving the Design of Existing Code](https://martinfowler.com/books/refactoring.html)

## Notes
- This is a classic "big ball of mud" refactoring challenge
- Incremental approach is critical - don't try to refactor everything at once
- Each extraction should be tested and deployed before next extraction
- Backwards compatibility is essential - existing automations depend on these scripts
- Good candidate for "boy scout rule" - improve each time you touch it
