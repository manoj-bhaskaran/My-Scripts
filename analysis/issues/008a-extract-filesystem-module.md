# Issue #008a: Extract Common FileSystem Module

**Parent Issue**: [#008: Large Complex Scripts](./008-large-complex-scripts.md)
**Phase**: Phase 1 - Common Modules
**Effort**: 8 hours

## Description
Extract file system operations used across multiple scripts into a shared module. This is the foundation for refactoring large scripts.

## Scope
Extract these operations from FileDistributor.ps1, Expand-ZipsAndClean.ps1, and others:
- Directory creation with error handling
- File existence/accessibility checks
- Path validation
- File locking detection

## Implementation

### Module Structure
```
src/powershell/modules/Core/FileSystem/
├── FileSystem.psd1
├── FileSystem.psm1
├── Public/
│   ├── New-DirectoryIfMissing.ps1
│   ├── Test-FileAccessible.ps1
│   ├── Test-PathValid.ps1
│   └── Test-FileLocked.ps1
└── Private/
    └── Get-FileLockInfo.ps1
```

### New-DirectoryIfMissing.ps1
```powershell
function New-DirectoryIfMissing {
    <#
    .SYNOPSIS
        Creates a directory if it doesn't exist.

    .PARAMETER Path
        Directory path to create

    .PARAMETER Force
        Create parent directories if needed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Force
    )

    if (Test-Path $Path) {
        Write-Verbose "Directory already exists: $Path"
        return Get-Item -Path $Path
    }

    try {
        $params = @{
            ItemType = 'Directory'
            Path = $Path
            Force = $Force
        }
        $dir = New-Item @params
        Write-Verbose "Created directory: $Path"
        return $dir
    }
    catch {
        Write-Error "Failed to create directory '$Path': $_"
        throw
    }
}
```

### Test-FileAccessible.ps1
```powershell
function Test-FileAccessible {
    <#
    .SYNOPSIS
        Tests if a file can be accessed for reading/writing.

    .PARAMETER Path
        File path to test

    .PARAMETER Access
        Type of access to test (Read, Write, ReadWrite)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('Read', 'Write', 'ReadWrite')]
        [string]$Access = 'Read'
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    try {
        $file = Get-Item -Path $Path -ErrorAction Stop

        switch ($Access) {
            'Read' {
                $stream = [System.IO.File]::OpenRead($Path)
                $stream.Close()
                return $true
            }
            'Write' {
                $stream = [System.IO.File]::OpenWrite($Path)
                $stream.Close()
                return $true
            }
            'ReadWrite' {
                return (Test-FileAccessible -Path $Path -Access Read) -and
                       (Test-FileAccessible -Path $Path -Access Write)
            }
        }
    }
    catch [System.IO.IOException] {
        Write-Verbose "File not accessible: $_"
        return $false
    }
    catch {
        Write-Verbose "Error checking file access: $_"
        return $false
    }
}
```

### Test-FileLocked.ps1
```powershell
function Test-FileLocked {
    <#
    .SYNOPSIS
        Tests if a file is locked by another process.

    .PARAMETER Path
        File path to test
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    try {
        $file = [System.IO.File]::Open(
            $Path,
            'Open',
            'ReadWrite',
            'None'
        )
        $file.Close()
        return $false  # Not locked
    }
    catch [System.IO.IOException] {
        return $true  # Locked
    }
    catch {
        Write-Warning "Unexpected error checking file lock: $_"
        return $false
    }
}
```

## Testing
```powershell
# tests/powershell/unit/FileSystem.Tests.ps1
Describe "FileSystem Module" {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../../src/powershell/modules/Core/FileSystem" -Force
    }

    Context "New-DirectoryIfMissing" {
        It "Creates new directory" {
            $path = "TestDrive:/NewDir"
            New-DirectoryIfMissing -Path $path
            Test-Path $path | Should -Be $true
        }

        It "Returns existing directory without error" {
            $path = "TestDrive:/Existing"
            New-Item -ItemType Directory -Path $path
            { New-DirectoryIfMissing -Path $path } | Should -Not -Throw
        }
    }

    Context "Test-FileAccessible" {
        It "Returns true for accessible file" {
            $file = "TestDrive:/test.txt"
            "content" | Out-File $file
            Test-FileAccessible -Path $file | Should -Be $true
        }

        It "Returns false for non-existent file" {
            Test-FileAccessible -Path "TestDrive:/missing.txt" | Should -Be $false
        }
    }

    Context "Test-FileLocked" {
        It "Detects unlocked file" {
            $file = "TestDrive:/unlocked.txt"
            "content" | Out-File $file
            Test-FileLocked -Path $file | Should -Be $false
        }
    }
}
```

## Migration Plan
1. Create module structure
2. Implement functions with tests
3. Update FileDistributor.ps1 to use module:
   ```powershell
   # Before
   try { New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null } catch { }

   # After
   Import-Module FileSystem
   New-DirectoryIfMissing -Path $DirectoryPath -Force
   ```
4. Update other scripts gradually
5. Document module usage

## Acceptance Criteria
- [ ] FileSystem module created with 4+ functions
- [ ] All functions have proper error handling
- [ ] Unit tests written (coverage > 60%)
- [ ] At least 3 scripts updated to use module
- [ ] Documentation written

## Benefits
- Reusable file operations
- Consistent error handling
- Easier to test
- Reduces code in large scripts
- Foundation for further refactoring

## Effort
8 hours

## Related
- Issue #008b (extract queue module)
- Issue #001 (replaces empty catch blocks with proper handling)
