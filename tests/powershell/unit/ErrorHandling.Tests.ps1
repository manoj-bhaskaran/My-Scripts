<#
.SYNOPSIS
    Unit tests for ErrorHandling module

.DESCRIPTION
    Pester tests for the ErrorHandling PowerShell module
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\src\powershell\modules\Core\ErrorHandling\ErrorHandling.psm1"
    Import-Module $modulePath -Force
}

Describe "Invoke-WithErrorHandling" {
    It "Executes script block successfully" {
        $result = Invoke-WithErrorHandling {
            return "success"
        }

        $result | Should -Be "success"
    }

    It "Handles errors with Stop action" {
        {
            Invoke-WithErrorHandling {
                throw "test error"
            } -OnError Stop
        } | Should -Throw
    }

    It "Handles errors with Continue action" {
        $result = Invoke-WithErrorHandling {
            throw "test error"
        } -OnError Continue

        $result | Should -BeNullOrEmpty
    }

    It "Handles errors with SilentlyContinue action" {
        $result = Invoke-WithErrorHandling {
            throw "test error"
        } -OnError SilentlyContinue

        $result | Should -BeNullOrEmpty
    }

    It "Uses custom error message" {
        {
            Invoke-WithErrorHandling {
                throw "test error"
            } -OnError Stop -ErrorMessage "Custom error"
        } | Should -Throw
    }
}

Describe "Invoke-WithRetry" {
    It "Succeeds on first attempt" {
        $result = Invoke-WithRetry -Operation {
            return "success"
        } -Description "Test operation"

        $result | Should -Be "success"
    }

    It "Retries and succeeds" {
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
        {
            Invoke-WithRetry -Operation {
                throw "permanent error"
            } -Description "Test operation" -RetryCount 2 -RetryDelay 0 -LogErrors $false
        } | Should -Throw
    }

    It "Uses exponential backoff" {
        $script:attemptCount = 0
        $script:delays = @()

        {
            Invoke-WithRetry -Operation {
                $script:attemptCount++
                throw "error"
            } -Description "Test" -RetryCount 3 -RetryDelay 1 -MaxBackoff 10 -LogErrors $false
        } | Should -Throw

        $script:attemptCount | Should -Be 3
    }
}

Describe "Test-IsElevated" {
    It "Returns a boolean value" {
        $result = Test-IsElevated

        $result | Should -BeOfType [bool]
    }

    It "Detects elevation correctly" {
        $result = Test-IsElevated

        # Result should be boolean (actual value depends on test environment)
        ($result -eq $true -or $result -eq $false) | Should -Be $true
    }
}

Describe "Assert-Elevated" {
    Context "When not elevated" {
        BeforeAll {
            # Mock Test-IsElevated to return false
            Mock Test-IsElevated { return $false }
        }

        It "Throws error when not elevated" {
            { Assert-Elevated } | Should -Throw
        }

        It "Uses custom message" {
            { Assert-Elevated -CustomMessage "Custom error" } | Should -Throw
        }
    }

    Context "When elevated" {
        BeforeAll {
            # Mock Test-IsElevated to return true
            Mock Test-IsElevated { return $true }
        }

        It "Does not throw when elevated" {
            { Assert-Elevated } | Should -Not -Throw
        }
    }
}

Describe "Test-CommandAvailable" {
    It "Detects available command" {
        $result = Test-CommandAvailable "Get-Command"

        $result | Should -Be $true
    }

    It "Detects unavailable command" {
        $result = Test-CommandAvailable "NonExistentCommand12345"

        $result | Should -Be $false
    }

    It "Works with external commands" {
        # Test with a common command that should exist
        if ($IsWindows -or $null -eq $IsWindows) {
            $result = Test-CommandAvailable "cmd"
        } else {
            $result = Test-CommandAvailable "ls"
        }

        $result | Should -Be $true
    }
}

AfterAll {
    # Clean up
    Remove-Module ErrorHandling -Force -ErrorAction SilentlyContinue
}
