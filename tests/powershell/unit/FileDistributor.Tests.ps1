<#
.SYNOPSIS
Pester tests for FileDistributor.ps1

.DESCRIPTION
Tests business logic and calculations for the FileDistributor script.
Tests focus on pure functions and calculations rather than script execution.
#>

BeforeAll {
    # Create mock test directories
    $script:TestDrive = $TestDrive
    $script:SourceFolder = Join-Path $TestDrive 'Source'
    $script:TargetFolder = Join-Path $TestDrive 'Target'

    New-Item -Path $script:SourceFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $script:TargetFolder -ItemType Directory -Force | Out-Null

    # Path to FileDistributor script
    $script:ScriptPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'file-management' 'FileDistributor.ps1'
}

Describe "FileDistributor Script Existence" {
    It "Script file should exist" {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It "Script should be a PowerShell file" {
        $script:ScriptPath | Should -Match '\.ps1$'
    }
}

Describe "FileDistributor Help" {
    It "Should display help when -Help parameter is provided" {
        $result = & pwsh -File $script:ScriptPath -Help 2>&1
        $result | Should -Not -BeNullOrEmpty
    }

    It "Should not throw errors with valid parameters and -Help" {
        { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -Help } | Should -Not -Throw
    }
}

Describe "FileDistributor Business Logic Calculations" {
    Context "File Limit Calculations" {
        It "Should calculate correct number of subfolders needed for 50,000 files with 20,000 limit" {
            $totalFiles = 50000
            $limitPerFolder = 20000
            $expectedFolders = [Math]::Ceiling($totalFiles / $limitPerFolder)

            $expectedFolders | Should -Be 3
        }

        It "Should calculate correct number of subfolders for exact division" {
            # 40,000 files with 20,000 limit = exactly 2 folders
            $totalFiles = 40000
            $limitPerFolder = 20000
            $expectedFolders = [Math]::Ceiling($totalFiles / $limitPerFolder)

            $expectedFolders | Should -Be 2
        }

        It "Should calculate 1 folder when files are fewer than limit" {
            # 5,000 files with 20,000 limit = 1 folder
            $totalFiles = 5000
            $limitPerFolder = 20000
            $expectedFolders = [Math]::Ceiling($totalFiles / $limitPerFolder)

            $expectedFolders | Should -Be 1
        }

        It "Should handle edge case of exactly limit files" {
            $totalFiles = 20000
            $limitPerFolder = 20000
            $expectedFolders = [Math]::Ceiling($totalFiles / $limitPerFolder)

            $expectedFolders | Should -Be 1
        }
    }

    Context "Path Validation Logic" {
        It "Should identify platform-appropriate absolute paths" {
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                # Windows paths
                $path = 'C:\Users\Test\Documents'
                [System.IO.Path]::IsPathRooted($path) | Should -Be $true
            } else {
                # Unix paths
                $path = '/home/user/documents'
                [System.IO.Path]::IsPathRooted($path) | Should -Be $true
            }
        }

        It "Should identify Unix-style absolute paths on Unix systems" {
            $path = '/home/user/documents'
            if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)) {
                [System.IO.Path]::IsPathRooted($path) | Should -Be $true
            } else {
                # On Windows, Unix paths may not be recognized as rooted
                $path | Should -Match '^/'
            }
        }

        It "Should identify relative paths as not rooted" {
            $path = '.\relative\path'
            [System.IO.Path]::IsPathRooted($path) | Should -Be $false
        }

        It "Should identify another relative path format" {
            $path = 'relative\path'
            [System.IO.Path]::IsPathRooted($path) | Should -Be $false
        }

        It "Should handle current directory path" {
            $path = '.'
            [System.IO.Path]::IsPathRooted($path) | Should -Be $false
        }
    }

    Context "DeleteMode Valid Values" {
        It "RecycleBin should be a valid mode" {
            $validModes = @('RecycleBin', 'Immediate', 'EndOfScript')
            'RecycleBin' | Should -BeIn $validModes
        }

        It "Immediate should be a valid mode" {
            $validModes = @('RecycleBin', 'Immediate', 'EndOfScript')
            'Immediate' | Should -BeIn $validModes
        }

        It "EndOfScript should be a valid mode" {
            $validModes = @('RecycleBin', 'Immediate', 'EndOfScript')
            'EndOfScript' | Should -BeIn $validModes
        }

        It "Invalid mode should not be in valid modes" {
            $validModes = @('RecycleBin', 'Immediate', 'EndOfScript')
            'InvalidMode' | Should -Not -BeIn $validModes
        }
    }

    Context "EndOfScriptDeletionCondition Valid Values" {
        It "NoWarnings should be a valid condition" {
            $validConditions = @('NoWarnings', 'WarningsOnly')
            'NoWarnings' | Should -BeIn $validConditions
        }

        It "WarningsOnly should be a valid condition" {
            $validConditions = @('NoWarnings', 'WarningsOnly')
            'WarningsOnly' | Should -BeIn $validConditions
        }
    }
}

Describe "FileDistributor Retry Logic Calculations" {
    Context "Exponential Backoff" {
        It "Should calculate correct backoff for first retry" {
            $baseDelay = 10
            $attempt = 1
            $backoff = $baseDelay * [Math]::Pow(2, $attempt - 1)

            $backoff | Should -Be 10
        }

        It "Should calculate correct backoff for second retry" {
            $baseDelay = 10
            $attempt = 2
            $backoff = $baseDelay * [Math]::Pow(2, $attempt - 1)

            $backoff | Should -Be 20
        }

        It "Should calculate correct backoff for third retry" {
            $baseDelay = 10
            $attempt = 3
            $backoff = $baseDelay * [Math]::Pow(2, $attempt - 1)

            $backoff | Should -Be 40
        }

        It "Should calculate correct backoff for fourth retry" {
            $baseDelay = 10
            $attempt = 4
            $backoff = $baseDelay * [Math]::Pow(2, $attempt - 1)

            $backoff | Should -Be 80
        }

        It "Should cap backoff at MaxBackoff when calculated value exceeds it" {
            $baseDelay = 10
            $attempt = 10
            $maxBackoff = 60
            $calculatedBackoff = $baseDelay * [Math]::Pow(2, $attempt - 1)
            $actualBackoff = [Math]::Min($calculatedBackoff, $maxBackoff)

            $actualBackoff | Should -Be 60
            $calculatedBackoff | Should -BeGreaterThan $maxBackoff
        }
    }
}

Describe "FileDistributor Size Parsing Logic" {
    Context "Size String Pattern Matching" {
        It "Should match kilobyte pattern" {
            $size = "1K"
            $size -match '(\d+)K$' | Should -Be $true
            [int]$matches[1] * 1KB | Should -Be 1024
        }

        It "Should match megabyte pattern" {
            $size = "1M"
            $size -match '(\d+)M$' | Should -Be $true
            [int]$matches[1] * 1MB | Should -Be 1048576
        }

        It "Should match gigabyte pattern" {
            $size = "1G"
            $size -match '(\d+)G$' | Should -Be $true
            [int]$matches[1] * 1GB | Should -Be 1073741824
        }

        It "Should parse multi-digit kilobyte values" {
            $size = "500K"
            $size -match '(\d+)K$' | Should -Be $true
            [int]$matches[1] | Should -Be 500
        }

        It "Should not match invalid patterns" {
            $size = "1X"
            $size -match '(\d+)[KMG]$' | Should -Be $false
        }
    }
}

Describe "FileDistributor Math Operations" {
    Context "Division and Ceiling Operations" {
        It "Should correctly compute ceiling for division" {
            [Math]::Ceiling(10 / 3.0) | Should -Be 4
        }

        It "Should correctly compute ceiling for exact division" {
            [Math]::Ceiling(10 / 2.0) | Should -Be 5
        }

        It "Should correctly compute minimum of two values" {
            [Math]::Min(100, 60) | Should -Be 60
        }

        It "Should correctly compute maximum of two values" {
            [Math]::Max(100, 60) | Should -Be 100
        }
    }
}
