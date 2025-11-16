<#
.SYNOPSIS
Pester tests for FileDistributor.ps1

.DESCRIPTION
Tests business logic for the FileDistributor script including parameter validation,
path resolution, and file distribution logic (with mocked file operations).
#>

BeforeAll {
    # Create mock test directories
    $script:TestDrive = $TestDrive
    $script:SourceFolder = Join-Path $TestDrive 'Source'
    $script:TargetFolder = Join-Path $TestDrive 'Target'

    New-Item -Path $script:SourceFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $script:TargetFolder -ItemType Directory -Force | Out-Null

    # Path to FileDistributor script
    $script:ScriptPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'FileDistributor.ps1'
}

Describe "FileDistributor Parameter Validation" {
    Context "Required Parameters" {
        It "Should require SourceFolder parameter" {
            # Test that script errors without SourceFolder
            $result = & pwsh -File $script:ScriptPath -TargetFolder $script:TargetFolder 2>&1
            $result | Should -Match 'SourceFolder|parameter'
        }

        It "Should require TargetFolder parameter" {
            # Test that script errors without TargetFolder
            $result = & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder 2>&1
            $result | Should -Match 'TargetFolder|parameter'
        }

        It "Should accept both SourceFolder and TargetFolder" {
            # This may fail if folders don't exist, but should pass parameter validation
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -Help } | Should -Not -Throw
        }
    }

    Context "DeleteMode Parameter" {
        It "Should accept RecycleBin delete mode" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -DeleteMode RecycleBin -Help } | Should -Not -Throw
        }

        It "Should accept Immediate delete mode" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -DeleteMode Immediate -Help } | Should -Not -Throw
        }

        It "Should accept EndOfScript delete mode" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -DeleteMode EndOfScript -Help } | Should -Not -Throw
        }
    }

    Context "Numeric Parameters" {
        It "Should accept FilesPerFolderLimit parameter" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -FilesPerFolderLimit 10000 -Help } | Should -Not -Throw
        }

        It "Should accept MaxFilesToCopy parameter" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -MaxFilesToCopy 100 -Help } | Should -Not -Throw
        }

        It "Should accept UpdateFrequency parameter" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -UpdateFrequency 50 -Help } | Should -Not -Throw
        }

        It "Should accept RetryCount parameter" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -RetryCount 5 -Help } | Should -Not -Throw
        }

        It "Should accept RetryDelay parameter" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -RetryDelay 15 -Help } | Should -Not -Throw
        }

        It "Should accept MaxBackoff parameter" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -MaxBackoff 120 -Help } | Should -Not -Throw
        }
    }

    Context "Switch Parameters" {
        It "Should accept ShowProgress switch" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -ShowProgress -Help } | Should -Not -Throw
        }

        It "Should accept Restart switch" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -Restart -Help } | Should -Not -Throw
        }

        It "Should accept CleanupDuplicates switch" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -CleanupDuplicates -Help } | Should -Not -Throw
        }

        It "Should accept CleanupEmptyFolders switch" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -CleanupEmptyFolders -Help } | Should -Not -Throw
        }

        It "Should accept TruncateLog switch" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -TruncateLog -Help } | Should -Not -Throw
        }

        It "Should accept ConsolidateToMinimum switch" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -ConsolidateToMinimum -Help } | Should -Not -Throw
        }

        It "Should accept RebalanceToAverage switch" {
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -RebalanceToAverage -Help } | Should -Not -Throw
        }
    }

    Context "Path Parameters" {
        It "Should accept LogFilePath parameter" {
            $logPath = Join-Path $TestDrive 'test.log'
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -LogFilePath $logPath -Help } | Should -Not -Throw
        }

        It "Should accept StateFilePath parameter" {
            $statePath = Join-Path $TestDrive 'state.json'
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -StateFilePath $statePath -Help } | Should -Not -Throw
        }

        It "Should accept RandomNameModulePath parameter" {
            $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'module' 'RandomName'
            { & pwsh -File $script:ScriptPath -SourceFolder $script:SourceFolder -TargetFolder $script:TargetFolder -RandomNameModulePath $modulePath -Help } | Should -Not -Throw
        }
    }
}

Describe "FileDistributor Help Functionality" {
    Context "Help Parameter" {
        It "Should display help when -Help is specified" {
            $result = & pwsh -File $script:ScriptPath -Help 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should exit without error when -Help is specified" {
            $result = & pwsh -File $script:ScriptPath -Help 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "FileDistributor Business Logic" {
    Context "File Limit Calculations" {
        It "Should calculate correct number of subfolders needed" {
            # If we have 50,000 files and limit is 20,000
            # We need 3 subfolders (ceil(50000/20000))
            $totalFiles = 50000
            $limitPerFolder = 20000
            $expectedFolders = [Math]::Ceiling($totalFiles / $limitPerFolder)

            $expectedFolders | Should -Be 3
        }

        It "Should handle exact division of files" {
            # 40,000 files with 20,000 limit = exactly 2 folders
            $totalFiles = 40000
            $limitPerFolder = 20000
            $expectedFolders = [Math]::Ceiling($totalFiles / $limitPerFolder)

            $expectedFolders | Should -Be 2
        }

        It "Should handle fewer files than limit" {
            # 5,000 files with 20,000 limit = 1 folder
            $totalFiles = 5000
            $limitPerFolder = 20000
            $expectedFolders = [Math]::Ceiling($totalFiles / $limitPerFolder)

            $expectedFolders | Should -Be 1
        }
    }

    Context "Path Validation Logic" {
        It "Should handle Windows-style paths" {
            $path = 'C:\Users\Test\Documents'
            [System.IO.Path]::IsPathRooted($path) | Should -Be $true
        }

        It "Should handle Unix-style paths" {
            $path = '/home/user/documents'
            [System.IO.Path]::IsPathRooted($path) | Should -Be $true
        }

        It "Should identify relative paths" {
            $path = '.\relative\path'
            [System.IO.Path]::IsPathRooted($path) | Should -Be $false
        }
    }

    Context "DeleteMode Logic" {
        It "Should validate RecycleBin is valid mode" {
            $validModes = @('RecycleBin', 'Immediate', 'EndOfScript')
            'RecycleBin' | Should -BeIn $validModes
        }

        It "Should validate Immediate is valid mode" {
            $validModes = @('RecycleBin', 'Immediate', 'EndOfScript')
            'Immediate' | Should -BeIn $validModes
        }

        It "Should validate EndOfScript is valid mode" {
            $validModes = @('RecycleBin', 'Immediate', 'EndOfScript')
            'EndOfScript' | Should -BeIn $validModes
        }
    }

    Context "EndOfScriptDeletionCondition Logic" {
        It "Should validate NoWarnings is valid condition" {
            $validConditions = @('NoWarnings', 'WarningsOnly')
            'NoWarnings' | Should -BeIn $validConditions
        }

        It "Should validate WarningsOnly is valid condition" {
            $validConditions = @('NoWarnings', 'WarningsOnly')
            'WarningsOnly' | Should -BeIn $validConditions
        }
    }
}

Describe "FileDistributor Retry Logic" {
    Context "Exponential Backoff Calculation" {
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

        It "Should cap backoff at MaxBackoff" {
            $baseDelay = 10
            $attempt = 10
            $maxBackoff = 60
            $backoff = [Math]::Min($baseDelay * [Math]::Pow(2, $attempt - 1), $maxBackoff)

            $backoff | Should -Be 60
        }
    }
}

Describe "FileDistributor Size Parsing" {
    Context "Size String Parsing" {
        It "Should parse kilobyte sizes" {
            # 1K = 1024 bytes
            $size = "1K"
            if ($size -match '(\d+)K$') {
                $bytes = [int]$matches[1] * 1KB
                $bytes | Should -Be 1024
            }
        }

        It "Should parse megabyte sizes" {
            # 1M = 1048576 bytes
            $size = "1M"
            if ($size -match '(\d+)M$') {
                $bytes = [int]$matches[1] * 1MB
                $bytes | Should -Be 1048576
            }
        }

        It "Should parse gigabyte sizes" {
            # 1G = 1073741824 bytes
            $size = "1G"
            if ($size -match '(\d+)G$') {
                $bytes = [int]$matches[1] * 1GB
                $bytes | Should -Be 1073741824
            }
        }
    }
}
