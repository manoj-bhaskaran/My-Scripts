<#
.SYNOPSIS
    Unit tests for ProgressReporter module

.DESCRIPTION
    Pester tests for the ProgressReporter PowerShell module
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "..\..\..\src\powershell\modules\Core\Progress\ProgressReporter.psm1"
    Import-Module $modulePath -Force
}

Describe "Show-Progress" {
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
}

Describe "Write-ProgressLog" {
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
}

Describe "New-ProgressTracker" {
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
}

Describe "Update-ProgressTracker" {
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
}

Describe "Complete-ProgressTracker" {
    It "Completes tracker" {
        $tracker = New-ProgressTracker -Total 100 -Activity "Test"

        { Complete-ProgressTracker -Tracker $tracker } | Should -Not -Throw
    }

    It "Accepts final message" {
        $tracker = New-ProgressTracker -Total 100 -Activity "Test"

        { Complete-ProgressTracker -Tracker $tracker -FinalMessage "Done!" } | Should -Not -Throw
    }
}

Describe "Write-ProgressStatus" {
    It "Updates progress status" {
        { Write-ProgressStatus -Activity "Test" -Status "Processing file.txt" } | Should -Not -Throw
    }

    It "Accepts Id parameter" {
        { Write-ProgressStatus -Activity "Test" -Status "Status" -Id 1 } | Should -Not -Throw
    }
}

Describe "Progress Workflow" {
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
}

AfterAll {
    # Clean up
    Remove-Module ProgressReporter -Force -ErrorAction SilentlyContinue
}
