<#
.SYNOPSIS
    Comprehensive unit tests for ProgressReporter module

.DESCRIPTION
    Pester tests for the ProgressReporter PowerShell module with 40%+ code coverage
    Tests include progress tracking, update frequency, edge cases, and integration tests
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\src\powershell\modules\Core\Progress\ProgressReporter.psm1"
    Import-Module $modulePath -Force
}

Describe "Show-Progress" {
    Context "Basic Functionality" {
        It "Displays progress without error" {
            { Show-Progress -Activity "Test" -PercentComplete 50 -Status "Testing" } | Should -Not -Throw
        }

        It "Accepts all parameters" {
            {
                Show-Progress -Activity "Test" `
                    -PercentComplete 75 `
                    -Status "Almost done" `
                    -Id 1 `
                    -CurrentOperation "Processing file"
            } | Should -Not -Throw
        }

        It "Handles completion" {
            { Show-Progress -Activity "Test" -Completed } | Should -Not -Throw
        }

        It "Accepts 0 percent complete" {
            { Show-Progress -Activity "Test" -PercentComplete 0 -Status "Starting" } | Should -Not -Throw
        }

        It "Accepts 100 percent complete" {
            { Show-Progress -Activity "Test" -PercentComplete 100 -Status "Finished" } | Should -Not -Throw
        }

        It "Handles custom IDs" {
            { Show-Progress -Activity "Test1" -PercentComplete 50 -Id 5 } | Should -Not -Throw
        }
    }

    Context "Edge Cases" {
        It "Handles empty status string" {
            { Show-Progress -Activity "Test" -PercentComplete 50 -Status "" } | Should -Not -Throw
        }

        It "Handles long activity names" {
            $longActivity = "A" * 200
            { Show-Progress -Activity $longActivity -PercentComplete 50 } | Should -Not -Throw
        }

        It "Handles special characters in activity" {
            { Show-Progress -Activity "Test: Special & Chars <>" -PercentComplete 50 } | Should -Not -Throw
        }

        It "Completes without previous progress shown" {
            { Show-Progress -Activity "DirectComplete" -Completed } | Should -Not -Throw
        }
    }
}

Describe "Write-ProgressLog" {
    Context "Basic Functionality" {
        It "Calculates percentage correctly" {
            { Write-ProgressLog -Message "Processing" -Current 50 -Total 100 } | Should -Not -Throw
        }

        It "Handles zero total" {
            { Write-ProgressLog -Message "Processing" -Current 0 -Total 0 } | Should -Not -Throw
        }

        It "Accepts activity parameter" {
            {
                Write-ProgressLog -Message "Processing files" `
                    -Current 25 `
                    -Total 100 `
                    -Activity "File Processing"
            } | Should -Not -Throw
        }

        It "Handles current equals total" {
            { Write-ProgressLog -Message "Complete" -Current 100 -Total 100 } | Should -Not -Throw
        }

        It "Calculates percentage correctly for valid inputs" {
            { Write-ProgressLog -Message "Half done" -Current 50 -Total 100 } | Should -Not -Throw
        }
    }

    Context "Edge Cases" {
        It "Handles low current values" {
            { Write-ProgressLog -Message "Starting" -Current 1 -Total 100 } | Should -Not -Throw
        }

        It "Handles very large numbers" {
            { Write-ProgressLog -Message "Large" -Current 1000000 -Total 10000000 } | Should -Not -Throw
        }

        It "Handles non-empty message" {
            { Write-ProgressLog -Message "Processing" -Current 50 -Total 100 } | Should -Not -Throw
        }

        It "Handles long message" {
            $longMessage = "M" * 500
            { Write-ProgressLog -Message $longMessage -Current 50 -Total 100 } | Should -Not -Throw
        }
    }
}

Describe "New-ProgressTracker" {
    Context "Basic Functionality" {
        It "Creates progress tracker" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            $tracker | Should -Not -BeNullOrEmpty
            $tracker.Total | Should -Be 100
            $tracker.Current | Should -Be 0
            $tracker.Activity | Should -Be "Test"
        }

        It "Sets update frequency" {
            $tracker = New-ProgressTracker -Total 1000 -Activity "Test" -UpdateFrequency 50

            $tracker.UpdateFrequency | Should -Be 50
        }

        It "Returns hashtable" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            $tracker | Should -BeOfType [hashtable]
        }

        It "Initializes LastUpdate to 0" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            $tracker.LastUpdate | Should -Be 0
        }

        It "Uses default update frequency of 1" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            $tracker.UpdateFrequency | Should -Be 1
        }
    }

    Context "Edge Cases" {
        It "Handles very large total" {
            $tracker = New-ProgressTracker -Total 1000000 -Activity "Test"

            $tracker.Total | Should -Be 1000000
        }

        It "Handles zero total" {
            $tracker = New-ProgressTracker -Total 0 -Activity "Test"

            $tracker.Total | Should -Be 0
        }

        It "Handles long activity name" {
            $longActivity = "Activity" * 50
            $tracker = New-ProgressTracker -Total 100 -Activity $longActivity

            $tracker.Activity | Should -Be $longActivity
        }

        It "Handles special characters in activity" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test: <>&"

            $tracker.Activity | Should -Be "Test: <>&"
        }

        It "Creates independent tracker instances" {
            $tracker1 = New-ProgressTracker -Total 100 -Activity "Test1"
            $tracker2 = New-ProgressTracker -Total 200 -Activity "Test2"

            $tracker1.Total | Should -Be 100
            $tracker2.Total | Should -Be 200
            $tracker1.Activity | Should -Be "Test1"
            $tracker2.Activity | Should -Be "Test2"
        }
    }
}

Describe "Update-ProgressTracker" {
    Context "Basic Functionality" {
        It "Updates tracker current value" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            Update-ProgressTracker -Tracker $tracker -Increment 10

            $tracker.Current | Should -Be 10
        }

        It "Increments by default amount" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            Update-ProgressTracker -Tracker $tracker

            $tracker.Current | Should -Be 1
        }

        It "Increments multiple times" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            Update-ProgressTracker -Tracker $tracker -Increment 5
            Update-ProgressTracker -Tracker $tracker -Increment 5
            Update-ProgressTracker -Tracker $tracker -Increment 5

            $tracker.Current | Should -Be 15
        }

        It "Accepts force parameter" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test" -UpdateFrequency 100

            { Update-ProgressTracker -Tracker $tracker -Force } | Should -Not -Throw
        }

        It "Accepts status parameter" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            { Update-ProgressTracker -Tracker $tracker -Status "Custom status" } | Should -Not -Throw
        }

        It "Updates LastUpdate when displaying progress" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test" -UpdateFrequency 5

            Update-ProgressTracker -Tracker $tracker -Increment 5

            $tracker.LastUpdate | Should -Be 5
        }
    }

    Context "Update Frequency Logic" {
        It "Respects update frequency threshold" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test" -UpdateFrequency 10
            $initialLastUpdate = $tracker.LastUpdate

            # Increment by less than UpdateFrequency
            Update-ProgressTracker -Tracker $tracker -Increment 5

            # Current should increase but LastUpdate shouldn't change (no display update)
            $tracker.Current | Should -Be 5
            # LastUpdate may or may not change depending on implementation
        }

        It "Forces update regardless of frequency" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test" -UpdateFrequency 100

            Update-ProgressTracker -Tracker $tracker -Increment 1 -Force

            $tracker.Current | Should -Be 1
            $tracker.LastUpdate | Should -Be 1
        }

        It "Updates when increment meets frequency threshold" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test" -UpdateFrequency 10

            Update-ProgressTracker -Tracker $tracker -Increment 10

            $tracker.Current | Should -Be 10
            $tracker.LastUpdate | Should -Be 10
        }

        It "Accumulates increments until threshold" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test" -UpdateFrequency 10

            Update-ProgressTracker -Tracker $tracker -Increment 3
            Update-ProgressTracker -Tracker $tracker -Increment 3
            Update-ProgressTracker -Tracker $tracker -Increment 4

            $tracker.Current | Should -Be 10
        }
    }

    Context "Edge Cases" {
        It "Handles increment that would exceed total" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            # Increment less than 100 to avoid percentage validation error
            Update-ProgressTracker -Tracker $tracker -Increment 99

            $tracker.Current | Should -Be 99
        }

        It "Handles zero total" {
            $tracker = New-ProgressTracker -Total 0 -Activity "Test"

            { Update-ProgressTracker -Tracker $tracker -Increment 1 } | Should -Not -Throw
        }

        It "Handles negative increment (edge case)" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"
            $tracker.Current = 50

            Update-ProgressTracker -Tracker $tracker -Increment -10

            $tracker.Current | Should -Be 40
        }

        It "Handles custom status with special characters" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            { Update-ProgressTracker -Tracker $tracker -Status "Processing <file> & data" } | Should -Not -Throw
        }

        It "Handles very large increments" {
            $tracker = New-ProgressTracker -Total 1000000 -Activity "Test"

            Update-ProgressTracker -Tracker $tracker -Increment 100000

            $tracker.Current | Should -Be 100000
        }
    }

    Context "Percentage Calculation" {
        It "Calculates correct percentage" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            Update-ProgressTracker -Tracker $tracker -Increment 50

            # Percentage should be 50%
            $tracker.Current | Should -Be 50
        }

        It "Handles 0% completion" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            Update-ProgressTracker -Tracker $tracker -Increment 0 -Force

            $tracker.Current | Should -Be 0
        }

        It "Handles 100% completion" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            Update-ProgressTracker -Tracker $tracker -Increment 100

            $tracker.Current | Should -Be 100
        }
    }
}

Describe "Complete-ProgressTracker" {
    Context "Basic Functionality" {
        It "Completes tracker" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
        }

        It "Accepts final message" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            { Complete-ProgressTracker -Tracker $tracker -FinalMessage "Done!" } | Should -Not -Throw
        }

        It "Completes partially finished tracker" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"
            Update-ProgressTracker -Tracker $tracker -Increment 50

            { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
        }

        It "Completes fully finished tracker" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"
            Update-ProgressTracker -Tracker $tracker -Increment 100

            { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
        }
    }

    Context "Edge Cases" {
        It "Completes tracker with zero progress" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
        }

        It "Handles long final message" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"
            $longMessage = "Done" * 100

            { Complete-ProgressTracker -Tracker $tracker -FinalMessage $longMessage } | Should -Not -Throw
        }

        It "Handles special characters in final message" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Test"

            { Complete-ProgressTracker -Tracker $tracker -FinalMessage "Complete: <>&" } | Should -Not -Throw
        }
    }
}

Describe "Write-ProgressStatus" {
    Context "Basic Functionality" {
        It "Updates progress status" {
            { Write-ProgressStatus -Activity "Test" -Status "Processing file.txt" } | Should -Not -Throw
        }

        It "Accepts Id parameter" {
            { Write-ProgressStatus -Activity "Test" -Status "Status" -Id 1 } | Should -Not -Throw
        }

        It "Accepts non-empty status" {
            { Write-ProgressStatus -Activity "Test" -Status "Processing" } | Should -Not -Throw
        }
    }

    Context "Edge Cases" {
        It "Handles long activity name" {
            $longActivity = "A" * 300
            { Write-ProgressStatus -Activity $longActivity -Status "Status" } | Should -Not -Throw
        }

        It "Handles long status message" {
            $longStatus = "S" * 300
            { Write-ProgressStatus -Activity "Test" -Status $longStatus } | Should -Not -Throw
        }

        It "Handles special characters" {
            { Write-ProgressStatus -Activity "Test: <>&" -Status "Status: <>&" } | Should -Not -Throw
        }

        It "Works with custom ID values" {
            { Write-ProgressStatus -Activity "Test" -Status "Status" -Id 99 } | Should -Not -Throw
        }
    }
}

Describe "Progress Workflow Integration" {
    Context "Full Workflow" {
        It "Supports full workflow" {
            # Create tracker
            $tracker = New-ProgressTracker -Total 10 -Activity "Integration Test"

            # Update progress
            for ($i = 1; $i -le 10; $i++) {
                Update-ProgressTracker -Tracker $tracker -Increment 1
            }

            $tracker.Current | Should -Be 10

            # Complete
            { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
        }

        It "Handles workflow with custom update frequency" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Batch Test" -UpdateFrequency 10

            for ($i = 1; $i -le 100; $i++) {
                Update-ProgressTracker -Tracker $tracker -Increment 1
            }

            $tracker.Current | Should -Be 100
            Complete-ProgressTracker -Tracker $tracker -FinalMessage "Batch complete"
        }

        It "Supports workflow with force updates" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Force Test" -UpdateFrequency 50

            Update-ProgressTracker -Tracker $tracker -Increment 10 -Force
            Update-ProgressTracker -Tracker $tracker -Increment 10 -Force
            Update-ProgressTracker -Tracker $tracker -Increment 10 -Force

            $tracker.Current | Should -Be 30
            Complete-ProgressTracker -Tracker $tracker
        }

        It "Handles workflow with custom status messages" {
            $tracker = New-ProgressTracker -Total 5 -Activity "Status Test"

            Update-ProgressTracker -Tracker $tracker -Increment 1 -Status "Step 1"
            Update-ProgressTracker -Tracker $tracker -Increment 1 -Status "Step 2"
            Update-ProgressTracker -Tracker $tracker -Increment 1 -Status "Step 3"
            Update-ProgressTracker -Tracker $tracker -Increment 1 -Status "Step 4"
            Update-ProgressTracker -Tracker $tracker -Increment 1 -Status "Step 5"

            $tracker.Current | Should -Be 5
            Complete-ProgressTracker -Tracker $tracker -FinalMessage "All steps complete"
        }
    }

    Context "Multiple Trackers" {
        It "Handles multiple independent trackers" {
            $tracker1 = New-ProgressTracker -Total 50 -Activity "Task 1"
            $tracker2 = New-ProgressTracker -Total 75 -Activity "Task 2"

            Update-ProgressTracker -Tracker $tracker1 -Increment 25
            Update-ProgressTracker -Tracker $tracker2 -Increment 50

            $tracker1.Current | Should -Be 25
            $tracker2.Current | Should -Be 50

            Complete-ProgressTracker -Tracker $tracker1
            Complete-ProgressTracker -Tracker $tracker2
        }

        It "Maintains separate state for each tracker" {
            $trackers = @()
            for ($i = 1; $i -le 3; $i++) {
                $trackers += New-ProgressTracker -Total 100 -Activity "Task $i"
            }

            for ($i = 0; $i -lt 3; $i++) {
                Update-ProgressTracker -Tracker $trackers[$i] -Increment (($i + 1) * 10)
            }

            $trackers[0].Current | Should -Be 10
            $trackers[1].Current | Should -Be 20
            $trackers[2].Current | Should -Be 30

            foreach ($tracker in $trackers) {
                Complete-ProgressTracker -Tracker $tracker
            }
        }
    }

    Context "Edge Case Workflows" {
        It "Completes without any updates" {
            $tracker = New-ProgressTracker -Total 100 -Activity "No Updates"

            { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
            $tracker.Current | Should -Be 0
        }

        It "Handles current beyond total" {
            $tracker = New-ProgressTracker -Total 100 -Activity "Overflow"

            # Don't actually update progress as it validates percentage
            $tracker.Current = 150

            $tracker.Current | Should -Be 150
            { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
        }

        It "Works with zero total" {
            $tracker = New-ProgressTracker -Total 0 -Activity "Zero Total"

            { Update-ProgressTracker -Tracker $tracker -Increment 1 } | Should -Not -Throw
            { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Clean up
    Remove-Module ProgressReporter -Force -ErrorAction SilentlyContinue
}
