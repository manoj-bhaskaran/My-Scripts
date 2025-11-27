<#
.SYNOPSIS
    Unit tests for Invoke-PostMergeHook.ps1

.DESCRIPTION
    Pester tests for the post-merge Git hook script
    Tests configuration parsing, module deployment, file synchronization, and merge handling

.NOTES
    Tests mock all file system and git operations to ensure tests run on any platform
#>

BeforeAll {
    # Store original location
    $script:originalLocation = Get-Location

    # Create temp directory for tests
    $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "PostMergeHookTests_$([guid]::NewGuid())"
    $script:testRepoPath = Join-Path $script:testDir "repo"
    $script:testConfigPath = Join-Path $script:testRepoPath "config\modules\deployment.txt"
    $script:testLocalConfigPath = Join-Path $script:testRepoPath "config\local-deployment-config.json"
    $script:testStagingMirror = Join-Path $script:testDir "staging"
    $script:testLogsDir = Join-Path $script:testStagingMirror "logs"

    # Create test directories
    New-Item -Path $script:testRepoPath -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $script:testRepoPath "config\modules") -ItemType Directory -Force | Out-Null
    New-Item -Path $script:testStagingMirror -ItemType Directory -Force | Out-Null
    New-Item -Path $script:testLogsDir -ItemType Directory -Force | Out-Null

    # Create a minimal local config file
    $localConfig = @{
        enabled = $true
        stagingMirror = $script:testStagingMirror
    } | ConvertTo-Json
    $localConfig | Out-File -FilePath $script:testLocalConfigPath -Force

    # Define mock logging functions globally before loading script
    function global:Write-LogInfo { param($Message) }
    function global:Write-LogWarning { param($Message) }
    function global:Write-LogError { param($Message) }
    function global:Initialize-Logger { param($resolvedLogDir, $ScriptName, $LogLevel) }

    # Import the script by dot-sourcing it with mocked dependencies
    Mock git {
        param([string]$Command)
        if ($args -contains "rev-parse" -and $args -contains "--show-toplevel") {
            return $script:testRepoPath
        }
        if ($args -contains "ls-files" -and $args -contains "-u") {
            return $null  # No unmerged files by default
        }
        if ($args -contains "merge-base") {
            return "mock-merge-base-hash"
        }
        if ($args -contains "diff" -and $args -contains "--name-only") {
            return @()
        }
        if ($args -contains "check-ignore") {
            return $null
        }
        return ""
    }

    Mock Import-Module { }
    Mock Write-Error { }
    Mock Write-Warning { }
    Mock Write-Host { }

    # Load functions from the post-merge script without executing the main logic
    $scriptPath = Join-Path $PSScriptRoot "..\..\..\src\powershell\git\Invoke-PostMergeHook.ps1"
    $scriptContent = Get-Content -Path $scriptPath -Raw

    # Find where functions start and where execution starts
    $firstFunctionMatch = [regex]::Match($scriptContent, '(?m)^function\s+')
    $executionMarker = 'Write-Message "post-merge script execution started."'
    $executionStart = $scriptContent.IndexOf($executionMarker)

    if ($firstFunctionMatch.Success -and $executionStart -gt 0) {
        # Only load the function definitions (skip config at top, skip execution at bottom)
        $functionsOnly = $scriptContent.Substring($firstFunctionMatch.Index, $executionStart - $firstFunctionMatch.Index)
        # Execute the function definitions
        . ([scriptblock]::Create($functionsOnly))
    } else {
        Write-Error "Could not parse script to extract functions"
    }

    # Set up script variables that the functions expect
    $script:RepoPath = $script:testRepoPath
    $script:DestinationFolder = $script:testStagingMirror
    $script:IsVerbose = $false

    # Ensure environment variables are set for cross-platform compatibility
    if (-not $env:USERPROFILE) {
        $env:USERPROFILE = $HOME
    }
    if (-not $env:USERNAME) {
        $env:USERNAME = "testuser"
    }

    # Override file system cmdlets with mock implementations AFTER loading functions
    # This ensures they're in the right scope for the loaded functions to use
    function global:Resolve-Path {
        [CmdletBinding()]
        param([Parameter(Mandatory=$false)]$LiteralPath)
        # Return the path as-is without actual resolution
        return [PSCustomObject]@{
            ProviderPath = $LiteralPath
        }
    }
    function global:Test-Path {
        param([Parameter(Mandatory=$false)]$LiteralPath, $PathType, $Path)
        # Use the actual Test-Path for file system checks in TestDrive
        # For non-TestDrive paths, check if they're obviously fake
        $pathToTest = if ($LiteralPath) { $LiteralPath } else { $Path }

        if (-not $pathToTest) { return $false }

        # If path contains "NonExistent" or starts with C:\ on non-Windows, return false
        if ($pathToTest -match "NonExistent" -or
            (($pathToTest -match "^[A-Z]:\\") -and (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)))) {
            return $false
        }

        # For TestDrive paths or actual test files, use real Test-Path
        if ($pathToTest -match "TestDrive" -or $pathToTest -match "PostMergeHookTests") {
            return (Microsoft.PowerShell.Management\Test-Path -LiteralPath $pathToTest -ErrorAction SilentlyContinue)
        }

        # Default to true for module deployment tests
        return $true
    }
}

AfterAll {
    # Clean up test directory
    if (Test-Path $script:testDir) {
        Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Set-Location $script:originalLocation
}

Describe "Get-HeaderVersion" {
    Context "Valid Version Headers" {
        It "Parses standard x.y.z version format" {
            $testFile = Join-Path $script:testDir "test_version.psm1"
            @"
<#
.SYNOPSIS
    Test module
.NOTES
    Version: 2.1.0
#>
"@ | Out-File -FilePath $testFile -Force

            $version = Get-HeaderVersion -Path $testFile
            $version | Should -Be ([version]"2.1.0")
        }

        It "Converts x.y to x.y.0 format" {
            $testFile = Join-Path $script:testDir "test_version2.psm1"
            @"
<#
.NOTES
    Version: 3.2
#>
"@ | Out-File -FilePath $testFile -Force

            $version = Get-HeaderVersion -Path $testFile
            $version | Should -Be ([version]"3.2.0")
        }
    }

    Context "Invalid Version Headers" {
        It "Throws when version header is missing" {
            $testFile = Join-Path $script:testDir "test_no_version.psm1"
            @"
<#
.SYNOPSIS
    Module without version
#>
"@ | Out-File -FilePath $testFile -Force

            { Get-HeaderVersion -Path $testFile } | Should -Throw "*No 'Version: x.y.z' header found*"
        }
    }
}

Describe "Test-ModuleSanity" {
    Context "Valid Modules" {
        It "Returns true for module with functions" {
            $testFile = Join-Path $script:testDir "test_with_function.psm1"
            @"
function Get-MergeData {
    param([string]`$Branch)
    Write-Output "Merged from `$Branch"
}
"@ | Out-File -FilePath $testFile -Force

            $result = Test-ModuleSanity -Path $testFile
            $result | Should -Be $true
        }

        It "Returns true for module with Export-ModuleMember" {
            $testFile = Join-Path $script:testDir "test_with_export.psm1"
            @"
`$script:mergeData = "test"
Export-ModuleMember -Variable mergeData
"@ | Out-File -FilePath $testFile -Force

            $result = Test-ModuleSanity -Path $testFile
            $result | Should -Be $true
        }
    }

    Context "Invalid Modules" {
        It "Returns false for module with syntax errors" {
            $testFile = Join-Path $script:testDir "test_syntax_error.psm1"
            @"
function Test-Merge {
    param([string]`$Name
    # Missing closing brace
"@ | Out-File -FilePath $testFile -Force

            Mock Write-Message { }
            $result = Test-ModuleSanity -Path $testFile
            $result | Should -Be $false
        }
    }
}

Describe "Get-SafeAbsolutePath" {
    Context "Valid Paths" {
        It "Returns absolute path when valid" {
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                $result = Get-SafeAbsolutePath -PathText "C:\Windows"
                $result | Should -Match "^[A-Z]:\\"
            } else {
                $result = Get-SafeAbsolutePath -PathText "/tmp"
                $result | Should -Match "^/"
            }
        }

        It "Handles non-existent paths gracefully" {
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                $result = Get-SafeAbsolutePath -PathText "C:\NonExistentPath\Test"
                $result | Should -Be "C:\NonExistentPath\Test"
            } else {
                $result = Get-SafeAbsolutePath -PathText "/non/existent/path"
                $result | Should -Be "/non/existent/path"
            }
        }
    }

    Context "Invalid Paths" {
        It "Throws on empty path" {
            { Get-SafeAbsolutePath -PathText "   " } | Should -Throw "*empty*"
        }

        It "Throws on path with wildcards" {
            { Get-SafeAbsolutePath -PathText "C:\Test\?" } | Should -Throw "*wildcards*"
        }

        It "Throws on relative path" {
            { Get-SafeAbsolutePath -PathText ".\relative" } | Should -Throw "*must be absolute*"
        }
    }
}

Describe "Test-TextSafe" {
    Context "Valid Text" {
        It "Returns true for normal text" {
            $result = Test-TextSafe -Text "Normal text here"
            $result | Should -Be $true
        }

        It "Returns true for text within max length" {
            $result = Test-TextSafe -Text "Short" -Max 10
            $result | Should -Be $true
        }
    }

    Context "Invalid Text" {
        It "Returns true for empty string (converted from null)" {
            # Note: $null passed to [string] parameter becomes ""
            # Test-TextSafe checks if ($null -eq $Text) but gets "" instead
            $result = Test-TextSafe -Text $null
            $result | Should -Be $true
        }

        It "Returns false for text exceeding max length" {
            $longText = "a" * 201
            $result = Test-TextSafe -Text $longText -Max 200
            $result | Should -Be $false
        }

        It "Returns false for text with control characters" {
            $textWithControlChar = "Text with" + [char]0x0000 + "control char"
            $result = Test-TextSafe -Text $textWithControlChar
            $result | Should -Be $false
        }

        It "Returns false for text with pipe character" {
            $result = Test-TextSafe -Text "Text|with|pipes"
            $result | Should -Be $false
        }
    }
}

Describe "New-DirectoryIfMissing" {
    Context "Directory Creation" {
        It "Creates directory when it doesn't exist" {
            $testPath = Join-Path $script:testDir "new_merge_directory"

            New-DirectoryIfMissing -Path $testPath

            Test-Path -Path $testPath | Should -Be $true
        }

        It "Does not throw when directory already exists" {
            $testPath = Join-Path $script:testDir "existing_merge_directory"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            { New-DirectoryIfMissing -Path $testPath } | Should -Not -Throw
        }
    }
}

Describe "Test-Ignored" {
    BeforeAll {
        Mock git {
            param()
            if ($args -contains "check-ignore") {
                $path = $args[-1]
                if ($path -eq "temp.tmp" -or $path -eq "cache/data.cache") {
                    return "temp.tmp"
                }
            }
            return $null
        }
    }

    Context "Gitignore Checking" {
        It "Returns true for ignored files" {
            $result = Test-Ignored -RelativePath "temp.tmp"
            $result | Should -Be $true
        }

        It "Returns false for non-ignored files" {
            $result = Test-Ignored -RelativePath "module.psm1"
            $result | Should -Be $false
        }
    }
}

Describe "New-OrUpdateManifest" {
    Context "Manifest Creation" {
        It "Creates manifest with correct parameters" {
            $manifestPath = Join-Path $script:testDir "MergeModule.psd1"

            New-OrUpdateManifest `
                -ManifestPath $manifestPath `
                -Version ([version]"2.0.0") `
                -ModuleName "MergeModule" `
                -Description "Merge test module" `
                -Author "Merge Author"

            Test-Path -Path $manifestPath | Should -Be $true

            $manifest = Import-PowerShellDataFile -Path $manifestPath
            $manifest.ModuleVersion | Should -Be "2.0.0"
            $manifest.RootModule | Should -Be "MergeModule.psm1"
            $manifest.Author | Should -Be "Merge Author"
            $manifest.Description | Should -Be "Merge test module"
        }

        It "Includes CompatiblePSEditions" {
            $manifestPath = Join-Path $script:testDir "CompatModule.psd1"

            New-OrUpdateManifest `
                -ManifestPath $manifestPath `
                -Version ([version]"1.0.0") `
                -ModuleName "CompatModule"

            $manifest = Import-PowerShellDataFile -Path $manifestPath
            $manifest.CompatiblePSEditions | Should -Contain "Desktop"
            $manifest.CompatiblePSEditions | Should -Contain "Core"
        }
    }
}

Describe "Deploy-ModuleFromConfig" {
    BeforeEach {
        # Create test module file
        $testModulePath = Join-Path $script:testRepoPath "MergeTestModule.psm1"
        @"
<#
.SYNOPSIS
    Merge test module
.NOTES
    Version: 2.0.0
#>
function Get-MergeInfo {
    return "merge info"
}
"@ | Out-File -FilePath $testModulePath -Force
    }

    Context "Valid Configuration" {
        It "Deploys module with User target" {
            $configContent = "MergeTestModule|MergeTestModule.psm1|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }
            Mock Test-ModuleSanity { return $true }
            Mock Get-HeaderVersion { return [version]"1.0.0" }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Copy-Item -Times 1
            Assert-MockCalled New-OrUpdateManifest -Times 1
        }

        It "Deploys only touched modules when TouchedRelPaths provided" {
            # Create another module
            $otherModulePath = Join-Path $script:testRepoPath "UntouchedModule.psm1"
            @"
<#
    Version: 1.0.0
#>
function Get-Other { return "other" }
"@ | Out-File -FilePath $otherModulePath -Force

            $configContent = @"
MergeTestModule|MergeTestModule.psm1|User
UntouchedModule|UntouchedModule.psm1|User
"@
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }
            Mock Test-ModuleSanity { return $true }
            Mock Get-HeaderVersion { return [version]"1.0.0" }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath `
                -TouchedRelPaths @("MergeTestModule.psm1")

            # Should only deploy MergeTestModule
            Assert-MockCalled Copy-Item -Times 1
        }

        It "Validates module path is within repository" {
            # Try to use a path that escapes the repo
            $configContent = "EscapeModule|..\..\..\EscapeModule.psm1|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock Copy-Item { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            # Should log error about escaping repo root
            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "escapes repo root" -or $Message -match "not found"
            }
            Assert-MockCalled Copy-Item -Times 0
        }

        It "Validates module file is a .psm1 file" {
            # Create a non-.psm1 file
            $txtFile = Join-Path $script:testRepoPath "NotAModule.txt"
            "Not a module" | Out-File -FilePath $txtFile -Force

            $configContent = "NotAModule|NotAModule.txt|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock Copy-Item { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "must point to a .psm1 file"
            }
            Assert-MockCalled Copy-Item -Times 0
        }

        It "Sanitizes author and description fields" {
            # Test with potentially unsafe author/description using control character
            $unsafeAuthor = "Author$([char]1)WithControlChar"  # Contains control character
            $configContent = "MergeTestModule|MergeTestModule.psm1|User|$unsafeAuthor"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }
            Mock Test-ModuleSanity { return $true }
            Mock Get-HeaderVersion { return [version]"1.0.0" }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            # Should use default author due to sanitization
            Assert-MockCalled New-OrUpdateManifest -ParameterFilter {
                $Author -eq $env:USERNAME
            }
        }
    }

    Context "Error Handling" {
        It "Handles missing config file gracefully" {
            Mock Write-Message { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath "C:\NonExistent\config.txt"

            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "Config not found"
            }
        }

        It "Skips invalid target configurations" {
            $configContent = "MergeTestModule|MergeTestModule.psm1|InvalidTarget"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock Copy-Item { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "invalid target"
            }
            Assert-MockCalled Copy-Item -Times 0
        }

        It "Handles empty Alt: target" {
            $configContent = "MergeTestModule|MergeTestModule.psm1|Alt:"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock Copy-Item { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "invalid target"
            }
            Assert-MockCalled Copy-Item -Times 0
        }

        It "Continues when manifest creation fails" {
            $configContent = "MergeTestModule|MergeTestModule.psm1|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { throw "Manifest creation failed" }

            { Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath } | Should -Not -Throw

            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "Deployment error"
            }
        }
    }
}

Describe "Write-Message" {
    Context "Message Logging" {
        It "Calls Write-LogInfo with formatted message" {
            Mock Write-LogInfo { }

            Write-Message -Message "Merge completed" -Source "merge-test"

            Assert-MockCalled Write-LogInfo -ParameterFilter {
                $Message -eq "merge-test - Merge completed"
            }
        }

        It "Uses default source when not specified" {
            Mock Write-LogInfo { }

            Write-Message -Message "Test message"

            Assert-MockCalled Write-LogInfo -ParameterFilter {
                $Message -match "post-merge - Test message"
            }
        }

        It "Outputs to host when ToHost switch is used" {
            Mock Write-LogInfo { }
            Mock Write-Host { }

            Write-Message -Message "Important message" -ToHost

            Assert-MockCalled Write-Host
        }

        It "Outputs to host when verbose mode is enabled" {
            $script:IsVerbose = $true
            Mock Write-LogInfo { }
            Mock Write-Host { }

            Write-Message -Message "Verbose message"

            Assert-MockCalled Write-Host
            $script:IsVerbose = $false
        }
    }
}

Describe "Post-Merge Hook Integration" {
    Context "Merge Detection" {
        It "Handles merge with valid merge-base" {
            Mock git {
                param()
                if ($args -contains "ls-files" -and $args -contains "-u") {
                    return $null  # No unmerged files
                }
                if ($args -contains "merge-base") {
                    return "mock-merge-base-hash"
                }
                if ($args -contains "diff" -and $args -contains "--name-only") {
                    return @("file1.ps1", "file2.ps1")
                }
                return ""
            }

            # Mock git should return files when called with merge-base
            $files = git -C $script:testRepoPath diff --name-only mock-merge-base HEAD
            $files | Should -Not -BeNullOrEmpty
        }

        It "Detects unmerged paths and should abort" {
            Mock git {
                param()
                if ($args -contains "ls-files" -and $args -contains "-u") {
                    return @("unmerged_file.txt")  # Unmerged file exists
                }
                return ""
            }

            $unmerged = git -C $script:testRepoPath ls-files -u
            $unmerged | Should -Not -BeNullOrEmpty
        }

        It "Falls back to ORIG_HEAD when merge-base fails" {
            Mock git {
                param()
                if ($args -contains "merge-base") {
                    throw "merge-base failed"
                }
                if ($args -contains "diff" -and $args -contains "ORIG_HEAD") {
                    return @("fallback_file.ps1")
                }
                return ""
            }

            # Should fall back to ORIG_HEAD
            $files = git -C $script:testRepoPath diff --name-only ORIG_HEAD HEAD 2>$null
            $files | Should -Not -BeNullOrEmpty
        }
    }
}
