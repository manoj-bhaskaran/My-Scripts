<#
.SYNOPSIS
    Unit tests for Invoke-PostCommitHook.ps1

.DESCRIPTION
    Pester tests for the post-commit Git hook script
    Tests configuration parsing, module deployment, file synchronization, and error handling

.NOTES
    Tests mock all file system and git operations to ensure tests run on any platform
#>

BeforeAll {
    # Store original location
    $script:originalLocation = Get-Location

    # Create temp directory for tests
    $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "PostCommitHookTests_$([guid]::NewGuid())"
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
    # We need to mock git and Import-Module before sourcing
    Mock git {
        param([string]$Command)
        if ($args -contains "rev-parse" -and $args -contains "--show-toplevel") {
            return $script:testRepoPath
        }
        if ($args -contains "diff" -and $args -contains "--name-only") {
            return @()
        }
        if ($args -contains "ls-tree") {
            return @()
        }
        if ($args -contains "check-ignore") {
            return $null
        }
        if ($args -contains "rev-parse" -and $args -contains "HEAD~1") {
            return "mock-commit-hash"
        }
        return ""
    }

    Mock Import-Module { }
    Mock Write-Error { }
    Mock Write-Warning { }
    Mock Write-Host { }

    # Load functions from the script without executing the main logic
    $scriptPath = Join-Path $PSScriptRoot "..\..\..\src\powershell\git\Invoke-PostCommitHook.ps1"
    $scriptContent = Get-Content -Path $scriptPath -Raw

    # Find where functions start and where execution starts
    $firstFunctionMatch = [regex]::Match($scriptContent, '(?m)^function\s+')
    $executionMarker = 'Write-Message "post-commit script execution started."'
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
    Version: 1.2.3
#>
"@ | Out-File -FilePath $testFile -Force

            $version = Get-HeaderVersion -Path $testFile
            $version | Should -Be ([version]"1.2.3")
        }

        It "Converts x.y to x.y.0 format" {
            $testFile = Join-Path $script:testDir "test_version2.psm1"
            @"
<#
.NOTES
    Version: 2.5
#>
"@ | Out-File -FilePath $testFile -Force

            $version = Get-HeaderVersion -Path $testFile
            $version | Should -Be ([version]"2.5.0")
        }

        It "Handles version with whitespace variations" {
            $testFile = Join-Path $script:testDir "test_version3.psm1"
            @"
<#
    Version:   3.1.4
#>
"@ | Out-File -FilePath $testFile -Force

            $version = Get-HeaderVersion -Path $testFile
            $version | Should -Be ([version]"3.1.4")
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

        It "Throws when version format is invalid" {
            $testFile = Join-Path $script:testDir "test_bad_version.psm1"
            @"
<#
    Version: invalid
#>
"@ | Out-File -FilePath $testFile -Force

            # Version: invalid doesn't match the numeric regex, so it throws "No version header found"
            { Get-HeaderVersion -Path $testFile } | Should -Throw "*No 'Version: x.y.z' header found*"
        }
    }
}

Describe "Test-ModuleSanity" {
    Context "Valid Modules" {
        It "Returns true for module with functions" {
            $testFile = Join-Path $script:testDir "test_with_function.psm1"
            @"
function Test-Function {
    param([string]`$Name)
    Write-Output "Hello `$Name"
}
"@ | Out-File -FilePath $testFile -Force

            $result = Test-ModuleSanity -Path $testFile
            $result | Should -Be $true
        }

        It "Returns true for module with Export-ModuleMember" {
            $testFile = Join-Path $script:testDir "test_with_export.psm1"
            @"
`$script:myVar = "test"
Export-ModuleMember -Variable myVar
"@ | Out-File -FilePath $testFile -Force

            $result = Test-ModuleSanity -Path $testFile
            $result | Should -Be $true
        }
    }

    Context "Invalid Modules" {
        It "Returns false for module with syntax errors" {
            $testFile = Join-Path $script:testDir "test_syntax_error.psm1"
            @"
function Test-Function {
    param([string]`$Name
    # Missing closing brace
"@ | Out-File -FilePath $testFile -Force

            Mock Write-Message { }
            $result = Test-ModuleSanity -Path $testFile
            $result | Should -Be $false
        }

        It "Returns false for empty module without functions or Export-ModuleMember" {
            $testFile = Join-Path $script:testDir "test_empty.psm1"
            @"
# Just a comment
`$someVar = "value"
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
                $result = Get-SafeAbsolutePath -PathText "C:\Program Files"
                $result | Should -Match "^[A-Z]:\\"
            } else {
                $result = Get-SafeAbsolutePath -PathText "/usr/local"
                $result | Should -Match "^/"
            }
        }

        It "Strips quotes from path" {
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                $result = Get-SafeAbsolutePath -PathText '"C:\Program Files"'
                $result | Should -Not -Match '"'
            } else {
                $result = Get-SafeAbsolutePath -PathText '"/usr/local"'
                $result | Should -Not -Match '"'
            }
        }
    }

    Context "Invalid Paths" {
        It "Throws on empty path" {
            { Get-SafeAbsolutePath -PathText "" } | Should -Throw "*empty*"
        }

        It "Throws on path with wildcards" {
            { Get-SafeAbsolutePath -PathText "C:\Test\*" } | Should -Throw "*wildcards*"
        }

        It "Throws on relative path" {
            { Get-SafeAbsolutePath -PathText "relative\path" } | Should -Throw "*must be absolute*"
        }
    }
}

Describe "New-DirectoryIfMissing" {
    Context "Directory Creation" {
        It "Creates directory when it doesn't exist" {
            $testPath = Join-Path $script:testDir "new_directory"

            New-DirectoryIfMissing -Path $testPath

            Test-Path -Path $testPath | Should -Be $true
        }

        It "Does not throw when directory already exists" {
            $testPath = Join-Path $script:testDir "existing_directory"
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
                if ($path -eq "ignored.log" -or $path -eq "logs/test.log") {
                    return "ignored.log"
                }
            }
            return $null
        }
    }

    Context "Gitignore Checking" {
        It "Returns true for ignored files" {
            $result = Test-Ignored -RelativePath "ignored.log"
            $result | Should -Be $true
        }

        It "Returns false for non-ignored files" {
            $result = Test-Ignored -RelativePath "important.ps1"
            $result | Should -Be $false
        }
    }
}

Describe "New-OrUpdateManifest" {
    Context "Manifest Creation" {
        It "Creates manifest with correct parameters" {
            $manifestPath = Join-Path $script:testDir "TestModule.psd1"

            New-OrUpdateManifest `
                -ManifestPath $manifestPath `
                -Version ([version]"1.0.0") `
                -ModuleName "TestModule" `
                -Description "Test Description" `
                -Author "Test Author"

            Test-Path -Path $manifestPath | Should -Be $true

            $manifest = Import-PowerShellDataFile -Path $manifestPath
            $manifest.ModuleVersion | Should -Be "1.0.0"
            $manifest.RootModule | Should -Be "TestModule.psm1"
            $manifest.Author | Should -Be "Test Author"
            $manifest.Description | Should -Be "Test Description"
        }

        It "Uses default values when optional parameters omitted" {
            $manifestPath = Join-Path $script:testDir "TestModule2.psd1"

            New-OrUpdateManifest `
                -ManifestPath $manifestPath `
                -Version ([version]"2.0.0") `
                -ModuleName "TestModule2"

            $manifest = Import-PowerShellDataFile -Path $manifestPath
            $manifest.Author | Should -Not -BeNullOrEmpty
            $manifest.Description | Should -Be "PowerShell module"
        }
    }
}

Describe "Deploy-ModuleFromConfig" {
    BeforeEach {
        # Create test module file
        $testModulePath = Join-Path $script:testRepoPath "TestModule.psm1"
        @"
<#
.SYNOPSIS
    Test module
.NOTES
    Version: 1.5.0
#>
function Get-TestData {
    return "test"
}
"@ | Out-File -FilePath $testModulePath -Force
    }

    Context "Valid Configuration" {
        It "Deploys module with System target" {
            # Skip on non-Windows
            if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)) {
                Set-ItResult -Skipped -Because "System target requires Windows"
                return
            }

            $configContent = "TestModule|TestModule.psm1|System|Test Author|Test module description"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Copy-Item -Times 1
            Assert-MockCalled New-OrUpdateManifest -Times 1
        }

        It "Deploys module with User target" {
            $configContent = "TestModule|TestModule.psm1|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }
            Mock Resolve-Path {
                param(
                    [Parameter(Mandatory=$false)]$LiteralPath
                )
                return [PSCustomObject]@{
                    ProviderPath = $LiteralPath
                }
            }
            Mock Test-Path {
                param(
                    [Parameter(Mandatory=$false)]$LiteralPath,
                    [Parameter(Mandatory=$false)]$Path,
                    [Parameter(Mandatory=$false)]$PathType
                )
                return $true
            }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Copy-Item -Times 1
        }

        It "Deploys module with Alt target" {
            $altPath = Join-Path $script:testDir "alt_modules"
            New-Item -Path $altPath -ItemType Directory -Force | Out-Null

            $configContent = "TestModule|TestModule.psm1|Alt:$altPath"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }
            Mock Resolve-Path {
                param(
                    [Parameter(Mandatory=$false)]$LiteralPath
                )
                return [PSCustomObject]@{
                    ProviderPath = $LiteralPath
                }
            }
            Mock Test-Path {
                param(
                    [Parameter(Mandatory=$false)]$LiteralPath,
                    [Parameter(Mandatory=$false)]$Path,
                    [Parameter(Mandatory=$false)]$PathType
                )
                return $true
            }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Copy-Item -Times 1
        }

        It "Deploys to multiple targets" {
            $altPath = Join-Path $script:testDir "alt_modules2"
            New-Item -Path $altPath -ItemType Directory -Force | Out-Null

            $configContent = "TestModule|TestModule.psm1|User,Alt:$altPath"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }
            Mock Resolve-Path {
                param(
                    [Parameter(Mandatory=$false)]$LiteralPath
                )
                return [PSCustomObject]@{
                    ProviderPath = $LiteralPath
                }
            }
            Mock Test-Path {
                param(
                    [Parameter(Mandatory=$false)]$LiteralPath,
                    [Parameter(Mandatory=$false)]$Path,
                    [Parameter(Mandatory=$false)]$PathType
                )
                return $true
            }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Copy-Item -Times 2
        }

        It "Only deploys modules in TouchedRelPaths when provided" {
            $configContent = @"
TestModule|TestModule.psm1|User
OtherModule|OtherModule.psm1|User
"@
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }
            Mock Resolve-Path {
                param(
                    [Parameter(Mandatory=$false)]$LiteralPath
                )
                return [PSCustomObject]@{
                    ProviderPath = $LiteralPath
                }
            }
            Mock Test-Path {
                param(
                    [Parameter(Mandatory=$false)]$LiteralPath,
                    [Parameter(Mandatory=$false)]$Path,
                    [Parameter(Mandatory=$false)]$PathType
                )
                return $true
            }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath `
                -TouchedRelPaths @("TestModule.psm1")

            # Should only deploy TestModule, not OtherModule
            Assert-MockCalled Copy-Item -Times 1
        }
    }

    Context "Configuration Parsing" {
        It "Skips comment lines" {
            $configContent = @"
# This is a comment
TestModule|TestModule.psm1|User
# Another comment
"@
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Copy-Item -Times 1
        }

        It "Skips empty lines" {
            $configContent = @"

TestModule|TestModule.psm1|User

"@
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Copy-Item -Times 1
        }

        It "Uses default author when not specified" {
            $configContent = "TestModule|TestModule.psm1|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled New-OrUpdateManifest -ParameterFilter {
                $Author -eq $env:USERNAME
            }
        }

        It "Uses custom author when specified" {
            $configContent = "TestModule|TestModule.psm1|User|Custom Author"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { }
            Mock New-OrUpdateManifest { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled New-OrUpdateManifest -ParameterFilter {
                $Author -eq "Custom Author"
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

        It "Skips deployment when module file doesn't exist" {
            $configContent = "NonExistentModule|NonExistent.psm1|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock Copy-Item { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "Module path not found"
            }
            Assert-MockCalled Copy-Item -Times 0
        }

        It "Skips deployment when module fails sanity check" {
            $badModulePath = Join-Path $script:testRepoPath "BadModule.psm1"
            @"
<#
    Version: 1.0.0
#>
# Empty module, no functions
`$var = 1
"@ | Out-File -FilePath $badModulePath -Force

            $configContent = "BadModule|BadModule.psm1|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock Copy-Item { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "failed sanity check"
            }
            Assert-MockCalled Copy-Item -Times 0
        }

        It "Handles invalid target gracefully" {
            $configContent = "TestModule|TestModule.psm1|InvalidTarget"
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

        It "Handles malformed config lines" {
            $configContent = "InvalidLineWithoutPipes"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock Copy-Item { }

            Deploy-ModuleFromConfig `
                -RepoPath $script:testRepoPath `
                -ConfigPath $script:testConfigPath

            Assert-MockCalled Write-Message -ParameterFilter {
                $Message -match "parse error"
            }
            Assert-MockCalled Copy-Item -Times 0
        }

        It "Continues deployment when copy operation fails" {
            $configContent = "TestModule|TestModule.psm1|User"
            $configContent | Out-File -FilePath $script:testConfigPath -Force

            Mock Write-Message { }
            Mock New-DirectoryIfMissing { }
            Mock Copy-Item { throw "Access denied" }
            Mock New-OrUpdateManifest { }

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

            Write-Message -Message "Test message" -Source "test-source"

            Assert-MockCalled Write-LogInfo -ParameterFilter {
                $Message -eq "test-source - Test message"
            }
        }

        It "Uses default source when not specified" {
            Mock Write-LogInfo { }

            Write-Message -Message "Test message"

            Assert-MockCalled Write-LogInfo -ParameterFilter {
                $Message -match "post-commit - Test message"
            }
        }

        It "Outputs to host when ToHost switch is used" {
            Mock Write-LogInfo { }
            Mock Write-Host { }

            Write-Message -Message "Test message" -ToHost

            Assert-MockCalled Write-Host
        }

        It "Outputs to host when verbose mode is enabled" {
            $script:IsVerbose = $true
            Mock Write-LogInfo { }
            Mock Write-Host { }

            Write-Message -Message "Test message"

            Assert-MockCalled Write-Host
            $script:IsVerbose = $false
        }
    }
}
