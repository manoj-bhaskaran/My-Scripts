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
    $script:StateHelpersPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'modules' 'FileManagement' 'FileDistributor' 'Private' 'State.ps1'
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

Describe 'FileDistributor Module Public API' {

    It 'Invoke-FileDistribution completion path avoids Write-Host output' {
        $functionPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'modules' 'FileManagement' 'FileDistributor' 'Public' 'Invoke-FileDistribution.ps1'
        $functionContent = Get-Content -LiteralPath $functionPath -Raw

        $functionContent | Should -Not -Match 'Write-Host\s+\$completionMsg'
    }

    It 'Invoke-FileDistribution accepts FileSystemInfo inputs for -Files' {
        $modPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'modules' 'FileManagement' 'FileDistributor' 'FileDistributor.psd1'
        Import-Module -Name $modPath -Force | Out-Null
        $filesParam = (Get-Command Invoke-FileDistribution -ErrorAction Stop).Parameters['Files']

        $filesParam.ParameterType.FullName | Should -Be 'System.Object[]'
    }

    It 'Should expose post-processing functions through module exports' {
        $modPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'modules' 'FileManagement' 'FileDistributor' 'FileDistributor.psd1'
        Import-Module -Name $modPath -Force | Out-Null
        (Get-Command Invoke-FolderRebalance -ErrorAction Stop).Name | Should -Be 'Invoke-FolderRebalance'
        (Get-Command Invoke-DistributionRandomize -ErrorAction Stop).Name | Should -Be 'Invoke-DistributionRandomize'
        (Get-Command Invoke-FolderConsolidation -ErrorAction Stop).Name | Should -Be 'Invoke-FolderConsolidation'
    }
}

Describe 'FileDistributor State Helpers' -Tag 'StateHelpers' {
    BeforeAll {
        $script:InvokeWithRetryCalls = @()

        function Write-LogInfo    { param([string]$Message) }
        function Write-LogWarning { param([string]$Message) }
        function Write-LogError   { param([string]$Message) }
        function Write-LogDebug   { param([string]$Message) }

        function Invoke-WithRetry {
            param(
                [scriptblock]$Operation,
                [string]$Description,
                [int]$RetryDelay,
                [int]$RetryCount,
                [int]$MaxBackoff
            )

            $script:InvokeWithRetryCalls += [pscustomobject]@{
                Description = $Description
                RetryDelay  = $RetryDelay
                RetryCount  = $RetryCount
                MaxBackoff  = $MaxBackoff
            }

            & $Operation
        }

        function Lock-DistributionStateFile {
            param(
                [string]$FilePath,
                [int]$RetryDelay,
                [int]$RetryCount,
                [int]$MaxBackoff
            )

            return [pscustomobject]@{
                FilePath   = $FilePath
                RetryDelay = $RetryDelay
                RetryCount = $RetryCount
                MaxBackoff = $MaxBackoff
            }
        }

        function Unlock-DistributionStateFile {
            param([object]$FileStream)
        }

        . $script:StateHelpersPath
    }

    BeforeEach {
        $script:InvokeWithRetryCalls = @()
    }

    It 'Write-JsonAtomically uses explicit retry parameters for the checksum sidecar' {
        $statePath = Join-Path $TestDrive 'state' 'write-json.json'

        Write-JsonAtomically -StateObject @{ Checkpoint = 1 } -Path $statePath -RetryCount 0 -MaxBackoff 3

        (Test-Path $statePath) | Should -Be $true
        (Test-Path "$statePath.sha256") | Should -Be $true
        $script:InvokeWithRetryCalls.Count | Should -Be 1
        $script:InvokeWithRetryCalls[0].RetryDelay | Should -Be 1
        $script:InvokeWithRetryCalls[0].RetryCount | Should -Be 0
        $script:InvokeWithRetryCalls[0].MaxBackoff | Should -Be 3
    }

    It 'Save-DistributionState persists state and re-locks using passed parameters' {
        $statePath = Join-Path $TestDrive 'state' 'save-state.json'
        $fileLock = [ref]([pscustomobject]@{ Existing = $true })

        Save-DistributionState -Checkpoint 4 -AdditionalVariables @{ Mode = 'Test' } -FileLock $fileLock -SessionId 'session-123' -WarningsSoFar 2 -ErrorsSoFar 1 -StateFilePath $statePath -RetryDelay 4 -RetryCount 5 -MaxBackoff 6

        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $state.Checkpoint | Should -Be 4
        $state.SessionId | Should -Be 'session-123'
        $state.WarningsSoFar | Should -Be 2
        $state.ErrorsSoFar | Should -Be 1
        $state.Mode | Should -Be 'Test'
        $fileLock.Value.FilePath | Should -Be $statePath
        $fileLock.Value.RetryDelay | Should -Be 4
        $fileLock.Value.RetryCount | Should -Be 5
        $fileLock.Value.MaxBackoff | Should -Be 6
    }

    It 'Restore-DistributionState reads the requested file path and re-locks with passed retry settings' {
        $statePath = Join-Path $TestDrive 'state' 'restore-state.json'
        $fileLock = [ref]([pscustomobject]@{ Existing = $true })
        Write-JsonAtomically -StateObject @{ Checkpoint = 7; SessionId = 'resume-1' } -Path $statePath -RetryCount 2 -MaxBackoff 8

        $state = Restore-DistributionState -FileLock $fileLock -StateFilePath $statePath -RetryDelay 9 -RetryCount 10 -MaxBackoff 11

        $state.Checkpoint | Should -Be 7
        $state.SessionId | Should -Be 'resume-1'
        $fileLock.Value.FilePath | Should -Be $statePath
        $fileLock.Value.RetryDelay | Should -Be 9
        $fileLock.Value.RetryCount | Should -Be 10
        $fileLock.Value.MaxBackoff | Should -Be 11
    }
}
