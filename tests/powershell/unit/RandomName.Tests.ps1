<#
.SYNOPSIS
Pester tests for RandomName PowerShell module

.DESCRIPTION
Tests the Get-RandomFileName function from the RandomName module,
including validation, character set compliance, and reserved name handling.
#>

BeforeAll {
    # Import the RandomName module
    $ModulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'modules' 'Utilities' 'RandomName' 'RandomName.psm1'
    Import-Module $ModulePath -Force
}

Describe "Get-RandomFileName" {
    Context "Basic Functionality" {
        It "Should generate a random file name" {
            $result = Get-RandomFileName
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should generate a string" {
            $result = Get-RandomFileName
            $result | Should -BeOfType [string]
        }

        It "Should generate different names on multiple calls" {
            $result1 = Get-RandomFileName
            $result2 = Get-RandomFileName
            $result3 = Get-RandomFileName

            # At least one should be different (extremely unlikely all three are the same)
            ($result1 -ne $result2) -or ($result2 -ne $result3) -or ($result1 -ne $result3) | Should -Be $true
        }
    }

    Context "Length Constraints" {
        It "Should respect default length range (4-32)" {
            $result = Get-RandomFileName
            $result.Length | Should -BeGreaterOrEqual 4
            $result.Length | Should -BeLessOrEqual 32
        }

        It "Should respect custom minimum length" {
            $result = Get-RandomFileName -MinimumLength 10
            $result.Length | Should -BeGreaterOrEqual 10
        }

        It "Should respect custom maximum length" {
            $result = Get-RandomFileName -MaximumLength 15
            $result.Length | Should -BeLessOrEqual 15
        }

        It "Should respect custom length range" {
            $results = 1..20 | ForEach-Object { Get-RandomFileName -MinimumLength 8 -MaximumLength 12 }
            $results | ForEach-Object {
                $_.Length | Should -BeGreaterOrEqual 8
                $_.Length | Should -BeLessOrEqual 12
            }
        }

        It "Should handle minimum length of 1" {
            $result = Get-RandomFileName -MinimumLength 1 -MaximumLength 5
            $result.Length | Should -BeGreaterOrEqual 1
            $result.Length | Should -BeLessOrEqual 5
        }

        It "Should handle maximum length equal to minimum length" {
            $result = Get-RandomFileName -MinimumLength 10 -MaximumLength 10
            $result.Length | Should -Be 10
        }
    }

    Context "Parameter Validation" {
        It "Should throw error when MaximumLength < MinimumLength" {
            { Get-RandomFileName -MinimumLength 20 -MaximumLength 10 } | Should -Throw
        }

        It "Should reject MinimumLength less than 1" {
            { Get-RandomFileName -MinimumLength 0 } | Should -Throw
        }

        It "Should reject MaximumLength greater than 255" {
            { Get-RandomFileName -MaximumLength 256 } | Should -Throw
        }

        It "Should reject negative MaximumLength" {
            { Get-RandomFileName -MaximumLength -5 } | Should -Throw
        }
    }

    Context "Character Set Compliance" {
        It "Should start with alphanumeric character" {
            $results = 1..50 | ForEach-Object { Get-RandomFileName }
            $results | ForEach-Object {
                $firstChar = $_.Substring(0, 1)
                $firstChar | Should -Match '^[a-zA-Z0-9]$'
            }
        }

        It "Should only contain allowed characters" {
            # Allowed: a-z, A-Z, 0-9, _, -, ~
            $results = 1..50 | ForEach-Object { Get-RandomFileName }
            $results | ForEach-Object {
                $_ | Should -Match '^[a-zA-Z0-9][a-zA-Z0-9_\-~]*$'
            }
        }

        It "Should not contain Windows invalid characters" {
            # Windows invalid: < > : " / \ | ? *
            $results = 1..50 | ForEach-Object { Get-RandomFileName }
            $results | ForEach-Object {
                $_ | Should -Not -Match '[<>:"/\\|?*]'
            }
        }

        It "Should not contain spaces" {
            $results = 1..50 | ForEach-Object { Get-RandomFileName }
            $results | ForEach-Object {
                $_ | Should -Not -Match '\s'
            }
        }

        It "Should not contain commas" {
            $results = 1..50 | ForEach-Object { Get-RandomFileName }
            $results | ForEach-Object {
                $_ | Should -Not -Match ','
            }
        }
    }

    Context "Reserved Device Name Avoidance" {
        It "Should not generate reserved device name CON" {
            # Generate many to increase confidence
            $results = 1..100 | ForEach-Object { Get-RandomFileName -MinimumLength 3 -MaximumLength 3 }
            $results | ForEach-Object {
                $_.ToUpper() | Should -Not -Be 'CON'
            }
        }

        It "Should not generate reserved device name PRN" {
            $results = 1..100 | ForEach-Object { Get-RandomFileName -MinimumLength 3 -MaximumLength 3 }
            $results | ForEach-Object {
                $_.ToUpper() | Should -Not -Be 'PRN'
            }
        }

        It "Should not generate reserved device name AUX" {
            $results = 1..100 | ForEach-Object { Get-RandomFileName -MinimumLength 3 -MaximumLength 3 }
            $results | ForEach-Object {
                $_.ToUpper() | Should -Not -Be 'AUX'
            }
        }

        It "Should not generate reserved device name NUL" {
            $results = 1..100 | ForEach-Object { Get-RandomFileName -MinimumLength 3 -MaximumLength 3 }
            $results | ForEach-Object {
                $_.ToUpper() | Should -Not -Be 'NUL'
            }
        }

        It "Should not generate reserved device names COM1-COM9" {
            $results = 1..200 | ForEach-Object { Get-RandomFileName -MinimumLength 4 -MaximumLength 4 }
            $results | ForEach-Object {
                $_.ToUpper() | Should -Not -Match '^COM[1-9]$'
            }
        }

        It "Should not generate reserved device names LPT1-LPT9" {
            $results = 1..200 | ForEach-Object { Get-RandomFileName -MinimumLength 4 -MaximumLength 4 }
            $results | ForEach-Object {
                $_.ToUpper() | Should -Not -Match '^LPT[1-9]$'
            }
        }

        It "Should handle MaxAttempts parameter" {
            # Should complete without hanging even with low MaxAttempts
            $result = Get-RandomFileName -MinimumLength 3 -MaximumLength 3 -MaxAttempts 10
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -Be 3
        }
    }

    Context "Edge Cases" {
        It "Should handle very short names (length 1)" {
            $result = Get-RandomFileName -MinimumLength 1 -MaximumLength 1
            $result.Length | Should -Be 1
            $result | Should -Match '^[a-zA-Z0-9]$'
        }

        It "Should handle very long names (near 255)" {
            $result = Get-RandomFileName -MinimumLength 250 -MaximumLength 255
            $result.Length | Should -BeGreaterOrEqual 250
            $result.Length | Should -BeLessOrEqual 255
        }

        It "Should be deterministic in structure" {
            # All results should follow the same pattern
            $results = 1..30 | ForEach-Object { Get-RandomFileName }
            $results | ForEach-Object {
                $_ | Should -Match '^[a-zA-Z0-9][a-zA-Z0-9_\-~]*$'
            }
        }
    }

    Context "MaxAttempts Parameter" {
        It "Should accept MaxAttempts parameter" {
            { Get-RandomFileName -MaxAttempts 50 } | Should -Not -Throw
        }

        It "Should respect MaxAttempts bounds (1-100000)" {
            { Get-RandomFileName -MaxAttempts 1 } | Should -Not -Throw
            { Get-RandomFileName -MaxAttempts 100000 } | Should -Not -Throw
        }

        It "Should reject MaxAttempts outside valid range" {
            { Get-RandomFileName -MaxAttempts 0 } | Should -Throw
            { Get-RandomFileName -MaxAttempts 100001 } | Should -Throw
        }

        It "Should complete even with MaxAttempts of 1" {
            # Even with only 1 attempt, function should return a valid name
            # (by forcing a safe first character if needed)
            $result = Get-RandomFileName -MinimumLength 3 -MaximumLength 3 -MaxAttempts 1
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -Be 3
        }
    }

    Context "Statistical Properties" {
        It "Should generate varied first characters" {
            $results = 1..100 | ForEach-Object { Get-RandomFileName }
            $firstChars = $results | ForEach-Object { $_.Substring(0, 1) }
            $uniqueFirstChars = $firstChars | Select-Object -Unique

            # Should have at least 10 different first characters in 100 tries
            $uniqueFirstChars.Count | Should -BeGreaterOrEqual 10
        }

        It "Should generate varied lengths within range" {
            $results = 1..100 | ForEach-Object { Get-RandomFileName -MinimumLength 5 -MaximumLength 15 }
            $lengths = $results | ForEach-Object { $_.Length }
            $uniqueLengths = $lengths | Select-Object -Unique

            # Should have multiple different lengths
            $uniqueLengths.Count | Should -BeGreaterOrEqual 3
        }
    }
}
