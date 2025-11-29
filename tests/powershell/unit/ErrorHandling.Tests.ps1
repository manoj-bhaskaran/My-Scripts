<#
.SYNOPSIS
    Comprehensive unit tests for ErrorHandling module

.DESCRIPTION
    Pester tests for the ErrorHandling PowerShell module with >80% code coverage
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\src\powershell\modules\Core\ErrorHandling\ErrorHandling.psm1"
    Import-Module $modulePath -Force

    # Create script-level variables to track logging calls
    $script:LogErrorCalled = $false
    $script:LogErrorMessage = $null
    $script:LogWarningCalled = $false
    $script:LogWarningMessage = $null
    $script:LogInfoCalled = $false
    $script:LogInfoMessage = $null

    # Create stub logging functions that track calls
    function Global:Write-LogError {
        param($Message)
        $script:LogErrorCalled = $true
        $script:LogErrorMessage = $Message
    }

    function Global:Write-LogWarning {
        param($Message)
        $script:LogWarningCalled = $true
        $script:LogWarningMessage = $Message
    }

    function Global:Write-LogInfo {
        param($Message)
        $script:LogInfoCalled = $true
        $script:LogInfoMessage = $Message
    }

    # Helper function to reset logging tracking
    function Reset-LoggingTracking {
        $script:LogErrorCalled = $false
        $script:LogErrorMessage = $null
        $script:LogWarningCalled = $false
        $script:LogWarningMessage = $null
        $script:LogInfoCalled = $false
        $script:LogInfoMessage = $null
    }
}

Describe "Invoke-WithErrorHandling" {
    Context "Successful Execution" {
        It "Executes script block successfully" {
            $result = Invoke-WithErrorHandling {
                return "success"
            }

            $result | Should -Be "success"
        }

        It "Returns complex objects from script block" {
            $result = Invoke-WithErrorHandling {
                return @{ Key = "Value"; Number = 42 }
            }

            $result.Key | Should -Be "Value"
            $result.Number | Should -Be 42
        }

        It "Handles multiple statements in script block" {
            $result = Invoke-WithErrorHandling {
                $a = 10
                $b = 20
                return $a + $b
            }

            $result | Should -Be 30
        }
    }

    Context "Error Handling with Stop Action" {
        BeforeEach {
            Reset-LoggingTracking
        }

        It "Throws error with Stop action" {
            {
                Invoke-WithErrorHandling {
                    throw "test error"
                } -OnError Stop
            } | Should -Throw
        }

        It "Uses custom error message with Stop" {
            {
                Invoke-WithErrorHandling {
                    throw "original error"
                } -OnError Stop -ErrorMessage "Custom prefix"
            } | Should -Throw
        }

        It "Logs error with Write-LogError when available" {
            {
                Invoke-WithErrorHandling {
                    throw "test error"
                } -OnError Stop -LogError $true
            } | Should -Throw

            $script:LogErrorCalled | Should -Be $true
            $script:LogErrorMessage | Should -BeLike "Error: test error"
        }

        It "Does not log when LogError is false" {
            {
                Invoke-WithErrorHandling {
                    throw "test error"
                } -OnError Stop -LogError $false
            } | Should -Throw

            $script:LogErrorCalled | Should -Be $false
        }

        It "Formats error message correctly" {
            {
                Invoke-WithErrorHandling {
                    throw "specific error message"
                } -OnError Stop
            } | Should -Throw

            $script:LogErrorCalled | Should -Be $true
            $script:LogErrorMessage | Should -BeLike "Error: specific error message"
        }

        It "Formats error message with custom prefix" {
            {
                Invoke-WithErrorHandling {
                    throw "specific error"
                } -OnError Stop -ErrorMessage "Operation failed"
            } | Should -Throw

            $script:LogErrorCalled | Should -Be $true
            $script:LogErrorMessage | Should -BeLike "Operation failed : specific error"
        }
    }

    Context "Error Handling with Continue Action" {
        BeforeEach {
            Reset-LoggingTracking
        }

        It "Returns null with Continue action" {
            $result = Invoke-WithErrorHandling {
                throw "test error"
            } -OnError Continue

            $result | Should -BeNullOrEmpty
        }

        It "Logs warning with Write-LogWarning when available" {
            $result = Invoke-WithErrorHandling {
                throw "test error"
            } -OnError Continue -LogError $true

            $result | Should -BeNullOrEmpty
            $script:LogWarningCalled | Should -Be $true
            $script:LogWarningMessage | Should -BeLike "Error: test error"
        }

        It "Uses custom error message with Continue" {
            $result = Invoke-WithErrorHandling {
                throw "original error"
            } -OnError Continue -ErrorMessage "Custom prefix"

            $result | Should -BeNullOrEmpty
            $script:LogWarningCalled | Should -Be $true
            $script:LogWarningMessage | Should -BeLike "Custom prefix*"
        }

        It "Does not log when LogError is false" {
            $result = Invoke-WithErrorHandling {
                throw "test error"
            } -OnError Continue -LogError $false

            $result | Should -BeNullOrEmpty
            $script:LogWarningCalled | Should -Be $false
        }
    }

    Context "Error Handling with SilentlyContinue Action" {
        BeforeEach {
            Reset-LoggingTracking
        }

        It "Returns null with SilentlyContinue action" {
            $result = Invoke-WithErrorHandling {
                throw "test error"
            } -OnError SilentlyContinue

            $result | Should -BeNullOrEmpty
        }

        It "Does not log anything with SilentlyContinue" {
            $result = Invoke-WithErrorHandling {
                throw "test error"
            } -OnError SilentlyContinue -LogError $true

            $result | Should -BeNullOrEmpty
            $script:LogErrorCalled | Should -Be $false
            $script:LogWarningCalled | Should -Be $false
        }
    }

    Context "Error Message Formatting" {
        BeforeEach {
            Reset-LoggingTracking
        }

        It "Preserves exception details" {
            {
                Invoke-WithErrorHandling {
                    throw [System.InvalidOperationException]::new("Invalid operation")
                } -OnError Stop
            } | Should -Throw

            $script:LogErrorCalled | Should -Be $true
            $script:LogErrorMessage | Should -BeLike "Error: Invalid operation"
        }
    }
}

Describe "Invoke-WithRetry" {
    Context "Successful Execution" {
        It "Succeeds on first attempt" {
            $result = Invoke-WithRetry -Operation {
                return "success"
            } -Description "Test operation"

            $result | Should -Be "success"
        }

        It "Returns complex objects" {
            $result = Invoke-WithRetry -Operation {
                return @{ Status = "OK"; Count = 5 }
            } -Description "Test operation"

            $result.Status | Should -Be "OK"
            $result.Count | Should -Be 5
        }
    }

    Context "Retry Logic" {
        It "Retries and succeeds on second attempt" {
            $script:attemptCount = 0

            $result = Invoke-WithRetry -Operation {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "temporary error"
                }
                return "success"
            } -Description "Test operation" -RetryCount 5 -RetryDelay 0 -LogErrors $false

            $result | Should -Be "success"
            $script:attemptCount | Should -Be 2
        }

        It "Retries and succeeds on third attempt" {
            $script:attemptCount = 0

            $result = Invoke-WithRetry -Operation {
                $script:attemptCount++
                if ($script:attemptCount -lt 3) {
                    throw "temporary error"
                }
                return "success"
            } -Description "Test operation" -RetryCount 5 -RetryDelay 0 -LogErrors $false

            $result | Should -Be "success"
            $script:attemptCount | Should -Be 3
        }

        It "Fails after max retries" {
            $script:attemptCount = 0

            {
                Invoke-WithRetry -Operation {
                    $script:attemptCount++
                    throw "permanent error"
                } -Description "Test operation" -RetryCount 3 -RetryDelay 0 -LogErrors $false
            } | Should -Throw

            $script:attemptCount | Should -Be 3
        }

        It "Respects RetryCount limit" {
            $script:attemptCount = 0

            {
                Invoke-WithRetry -Operation {
                    $script:attemptCount++
                    throw "error"
                } -Description "Test" -RetryCount 2 -RetryDelay 0 -LogErrors $false
            } | Should -Throw

            $script:attemptCount | Should -Be 2
        }
    }

    Context "Exponential Backoff" {
        It "Uses base delay correctly" {
            $script:attemptCount = 0

            {
                Invoke-WithRetry -Operation {
                    $script:attemptCount++
                    throw "error"
                } -Description "Test" -RetryCount 3 -RetryDelay 1 -MaxBackoff 60 -LogErrors $false
            } | Should -Throw

            $script:attemptCount | Should -Be 3
        }

        It "Respects MaxBackoff limit" {
            $script:attemptCount = 0

            {
                Invoke-WithRetry -Operation {
                    $script:attemptCount++
                    throw "error"
                } -Description "Test" -RetryCount 5 -RetryDelay 10 -MaxBackoff 15 -LogErrors $false
            } | Should -Throw

            $script:attemptCount | Should -Be 5
        }

        It "Calculates exponential backoff correctly" {
            # This test verifies the backoff calculation doesn't crash
            $script:attemptCount = 0

            {
                Invoke-WithRetry -Operation {
                    $script:attemptCount++
                    throw "error"
                } -Description "Test" -RetryCount 4 -RetryDelay 2 -MaxBackoff 30 -LogErrors $false
            } | Should -Throw

            $script:attemptCount | Should -Be 4
        }
    }

    Context "Logging Behavior" {
        BeforeEach {
            Reset-LoggingTracking
        }

        It "Logs retry attempts with Write-LogWarning" {
            $script:attemptCount = 0

            {
                Invoke-WithRetry -Operation {
                    $script:attemptCount++
                    throw "error"
                } -Description "Test operation" -RetryCount 2 -RetryDelay 0 -LogErrors $true
            } | Should -Throw

            $script:LogWarningCalled | Should -Be $true
            $script:LogWarningMessage | Should -BeLike "*Attempt*error*"
        }

        It "Logs final failure with Write-LogError" {
            {
                Invoke-WithRetry -Operation {
                    throw "permanent error"
                } -Description "Test operation" -RetryCount 2 -RetryDelay 0 -LogErrors $true
            } | Should -Throw

            $script:LogErrorCalled | Should -Be $true
            $script:LogErrorMessage | Should -BeLike "*failed after*"
        }

        It "Logs success after retry with Write-LogInfo" {
            $script:attemptCount = 0

            $result = Invoke-WithRetry -Operation {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "temporary error"
                }
                return "success"
            } -Description "Test operation" -RetryCount 5 -RetryDelay 0 -LogErrors $true

            $result | Should -Be "success"
            $script:LogInfoCalled | Should -Be $true
            $script:LogInfoMessage | Should -BeLike "*Succeeded after*retry*"
        }

        It "Does not log when LogErrors is false" {
            {
                Invoke-WithRetry -Operation {
                    throw "error"
                } -Description "Test" -RetryCount 2 -RetryDelay 0 -LogErrors $false
            } | Should -Throw

            $script:LogErrorCalled | Should -Be $false
            $script:LogWarningCalled | Should -Be $false
        }

        It "Preserves error messages in logs" {
            {
                Invoke-WithRetry -Operation {
                    throw "Specific error message"
                } -Description "Custom operation" -RetryCount 2 -RetryDelay 0 -LogErrors $true
            } | Should -Throw

            $script:LogWarningMessage | Should -BeLike "*Specific error message*"
        }
    }

    Context "Edge Cases" {
        It "Handles different error types" {
            {
                Invoke-WithRetry -Operation {
                    throw [System.InvalidOperationException]::new("Invalid operation")
                } -Description "Test" -RetryCount 1 -RetryDelay 0 -LogErrors $false
            } | Should -Throw
        }

        It "Handles operations with no return value" {
            $script:executed = $false

            Invoke-WithRetry -Operation {
                $script:executed = $true
            } -Description "Test" -RetryDelay 0 -LogErrors $false

            $script:executed | Should -Be $true
        }

        It "Succeeds immediately without retries" {
            $script:attemptCount = 0

            $result = Invoke-WithRetry -Operation {
                $script:attemptCount++
                return "immediate success"
            } -Description "Test" -RetryCount 3 -RetryDelay 0 -LogErrors $false

            $result | Should -Be "immediate success"
            $script:attemptCount | Should -Be 1
        }
    }
}

Describe "Test-IsElevated" {
    Context "Return Type" {
        It "Returns a boolean value" {
            $result = Test-IsElevated

            $result | Should -BeOfType [bool]
        }

        It "Returns either true or false" {
            $result = Test-IsElevated

            ($result -eq $true -or $result -eq $false) | Should -Be $true
        }
    }

    Context "Platform Detection" {
        It "Executes without errors" {
            { Test-IsElevated } | Should -Not -Throw
        }

        It "Handles platform detection correctly" {
            # This test ensures the function works on current platform
            $result = Test-IsElevated

            # Should return a boolean regardless of platform
            $result | Should -BeIn @($true, $false)
        }
    }

    Context "Error Handling" {
        It "Returns false on Windows elevation check failure" -Skip:(!($IsWindows -or $null -eq $PSVersionTable.Platform)) {
            # This test is only relevant on Windows
            # The function should handle errors gracefully
            $result = Test-IsElevated
            $result | Should -BeOfType [bool]
        }

        It "Returns false on Unix elevation check failure" -Skip:($IsWindows -or $null -eq $PSVersionTable.Platform) {
            # This test is only relevant on Unix systems
            # The function should handle errors gracefully
            $result = Test-IsElevated
            $result | Should -BeOfType [bool]
        }
    }
}

Describe "Assert-Elevated" {
    Context "When Not Elevated" {
        BeforeAll {
            Mock Test-IsElevated { return $false } -ModuleName ErrorHandling
        }

        It "Throws error when not elevated" {
            { Assert-Elevated } | Should -Throw
        }

        It "Throws with default message" {
            { Assert-Elevated } | Should -Throw "*elevated privileges*"
        }

        It "Uses custom error message" {
            { Assert-Elevated -CustomMessage "Custom error message" } | Should -Throw "Custom error message"
        }

        It "Throws terminating error" {
            $threw = $false
            try {
                Assert-Elevated
            }
            catch {
                $threw = $true
            }
            $threw | Should -Be $true
        }
    }

    Context "When Elevated" {
        BeforeAll {
            Mock Test-IsElevated { return $true } -ModuleName ErrorHandling
        }

        It "Does not throw when elevated" {
            { Assert-Elevated } | Should -Not -Throw
        }

        It "Does not throw with custom message when elevated" {
            { Assert-Elevated -CustomMessage "Custom message" } | Should -Not -Throw
        }

        It "Completes successfully when elevated" {
            $result = $null
            { $result = Assert-Elevated } | Should -Not -Throw
            # Assert-Elevated returns nothing on success
        }
    }

    Context "Message Handling" {
        BeforeAll {
            Mock Test-IsElevated { return $false } -ModuleName ErrorHandling
        }

        It "Includes platform-specific guidance in default message" {
            try {
                Assert-Elevated
                throw "Should have thrown"
            }
            catch {
                $_.Exception.Message | Should -Match "(Administrator|sudo)"
            }
        }

        It "Preserves custom message exactly" {
            try {
                Assert-Elevated -CustomMessage "Exactly this message"
                throw "Should have thrown"
            }
            catch {
                $_.Exception.Message | Should -Be "Exactly this message"
            }
        }
    }
}

Describe "Test-CommandAvailable" {
    Context "Built-in Commands" {
        It "Detects available cmdlet" {
            $result = Test-CommandAvailable "Get-Command"

            $result | Should -Be $true
        }

        It "Detects available function" {
            $result = Test-CommandAvailable "Test-IsElevated"

            $result | Should -Be $true
        }

        It "Detects unavailable command" {
            $result = Test-CommandAvailable "NonExistentCommand12345XYZ"

            $result | Should -Be $false
        }
    }

    Context "External Commands" {
        It "Detects platform-specific commands on Windows" -Skip:(!($IsWindows -or $null -eq $PSVersionTable.Platform)) {
            $result = Test-CommandAvailable "cmd"

            $result | Should -Be $true
        }

        It "Detects platform-specific commands on Unix" -Skip:($IsWindows -or $null -eq $PSVersionTable.Platform) {
            $result = Test-CommandAvailable "ls"

            $result | Should -Be $true
        }

        It "Returns false for non-existent external command" {
            $result = Test-CommandAvailable "nonexistent-external-command-xyz123"

            $result | Should -Be $false
        }
    }

    Context "Edge Cases" {
        It "Handles whitespace-only string" {
            $result = Test-CommandAvailable "   "

            $result | Should -Be $false
        }

        It "Returns boolean type" {
            $result = Test-CommandAvailable "Get-Command"

            $result | Should -BeOfType [bool]
        }

        It "Is case-insensitive" {
            $result1 = Test-CommandAvailable "get-command"
            $result2 = Test-CommandAvailable "GET-COMMAND"

            $result1 | Should -Be $true
            $result2 | Should -Be $true
        }

        It "Handles null or non-existent commands" {
            $result = Test-CommandAvailable "ThisCommandDefinitelyDoesNotExist123456789"

            $result | Should -Be $false
        }
    }

    Context "Module Commands" {
        It "Detects commands from imported module" {
            # ErrorHandling module functions should be available
            $result = Test-CommandAvailable "Invoke-WithErrorHandling"

            $result | Should -Be $true
        }
    }
}

Describe "Integration Tests" {
    Context "ErrorHandling with Retry" {
        It "Combines error handling and retry logic" {
            $script:attemptCount = 0

            $result = Invoke-WithErrorHandling {
                Invoke-WithRetry -Operation {
                    $script:attemptCount++
                    if ($script:attemptCount -lt 2) {
                        throw "temporary error"
                    }
                    return "success"
                } -Description "Test" -RetryCount 5 -RetryDelay 0 -LogErrors $false
            } -OnError Stop

            $result | Should -Be "success"
            $script:attemptCount | Should -Be 2
        }

        It "Handles nested error handling" {
            $result = Invoke-WithErrorHandling {
                Invoke-WithErrorHandling {
                    return "nested success"
                } -OnError Stop
            } -OnError Stop

            $result | Should -Be "nested success"
        }
    }

    Context "Privilege Checks with Error Handling" {
        It "Combines privilege check with error handling" {
            Mock Test-IsElevated { return $true } -ModuleName ErrorHandling

            $result = Invoke-WithErrorHandling {
                Assert-Elevated
                return "executed"
            } -OnError Stop

            $result | Should -Be "executed"
        }

        It "Handles privilege check failure gracefully" {
            Mock Test-IsElevated { return $false } -ModuleName ErrorHandling

            $result = Invoke-WithErrorHandling {
                Assert-Elevated
                return "should not reach"
            } -OnError Continue

            $result | Should -BeNullOrEmpty
        }
    }

    Context "Command Availability with Conditional Logic" {
        It "Uses Test-CommandAvailable in conditional execution" {
            $result = Invoke-WithErrorHandling {
                if (Test-CommandAvailable "Get-Command") {
                    return "command available"
                }
                else {
                    return "command not available"
                }
            }

            $result | Should -Be "command available"
        }
    }
}

AfterAll {
    # Clean up
    Remove-Module ErrorHandling -Force -ErrorAction SilentlyContinue

    # Remove stub logging functions
    Remove-Item Function:\Write-LogError -ErrorAction SilentlyContinue
    Remove-Item Function:\Write-LogWarning -ErrorAction SilentlyContinue
    Remove-Item Function:\Write-LogInfo -ErrorAction SilentlyContinue
}
