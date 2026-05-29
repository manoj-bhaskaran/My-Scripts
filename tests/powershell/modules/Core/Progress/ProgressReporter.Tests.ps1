Set-StrictMode -Version Latest

Describe 'Write-ExtractionSummary' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\..\..\..\src\powershell\modules\Core\Progress\ProgressReporter.psm1') -Force

        $script:defaultMoveSummary = [pscustomobject]@{
            Count = 3; Bytes = [int64]5000; Destination = 'C:\parent'
            Skipped = 0; Overwritten = 0; Renamed = 1
        }
        $script:emptyErrors = [System.Collections.Generic.List[string]]::new()
        $script:testElapsed = [timespan]::FromSeconds(2.5)
    }

    It 'emits interactive summary header and view payload' {
        Mock Format-Table -ModuleName ProgressReporter { }
        Mock Format-List -ModuleName ProgressReporter { }

        $allOutput = @(Write-ExtractionSummary `
            -SourceDirectory 'C:\mysrc' -DestinationDirectory 'C:\mydest' `
            -ExtractMode 'PerArchiveSubfolder' -CollisionPolicy 'Rename' `
            -ZipCount 7 -ProcessedZips 6 -FilesExtracted 30 `
            -UncompressedBytes ([int64]2000000) -CompressedBytes ([int64]600000) `
            -MoveSummary $script:defaultMoveSummary -Errors $script:emptyErrors `
            -Elapsed ([timespan]::FromSeconds(10)) -HostName 'ConsoleHost' -PassThru)

        $allOutput | Should -Contain '==== Expand-ZipsAndClean Summary ===='
        $view = $allOutput | Where-Object { $_ -isnot [string] } | Select-Object -First 1

        $view             | Should -Not -BeNullOrEmpty
        $view.SrcDir      | Should -Be 'C:\mysrc'
        $view.DestDir     | Should -Be 'C:\mydest'
        $view.ZipsFound   | Should -Be 7
        $view.ZipsDone    | Should -Be 6
        $view.Files       | Should -Be 30
        $view.Ratio       | Should -Be '3.3x'
        $view.Duration    | Should -BeLike '00:00:10*'
    }

    It 'suppresses summary table and header when non-interactive and no errors' {
        Mock Format-Table -ModuleName ProgressReporter { }
        Mock Format-List -ModuleName ProgressReporter { }

        $output = @(Write-ExtractionSummary `
            -SourceDirectory 'C:\src' -DestinationDirectory 'C:\dest' `
            -ExtractMode 'PerArchiveSubfolder' -CollisionPolicy 'Rename' `
            -ZipCount 5 -ProcessedZips 5 -FilesExtracted 20 `
            -UncompressedBytes ([int64]1000000) -CompressedBytes ([int64]300000) `
            -MoveSummary $script:defaultMoveSummary -Errors $script:emptyErrors `
            -Elapsed $script:testElapsed -HostName 'DefaultHost')

        $output.Count   | Should -Be 0
        Should -Invoke Format-Table -ModuleName ProgressReporter -Times 0
        Should -Invoke Format-List -ModuleName ProgressReporter -Times 0
    }

    It 'emits error notes even when host is non-interactive' {
        $errList = [System.Collections.Generic.List[string]]::new()
        $errList.Add('Archive is corrupt')
        Mock Format-Table -ModuleName ProgressReporter { }
        Mock Format-List -ModuleName ProgressReporter { }

        $output = @(Write-ExtractionSummary `
            -SourceDirectory 'C:\src' -DestinationDirectory 'C:\dest' `
            -ExtractMode 'Flat' -CollisionPolicy 'Skip' `
            -ZipCount 1 -ProcessedZips 0 -FilesExtracted 0 `
            -UncompressedBytes ([int64]0) -CompressedBytes ([int64]0) `
            -MoveSummary $script:defaultMoveSummary -Errors $errList `
            -Elapsed $script:testElapsed -HostName 'DefaultHost')

        Should -Invoke Format-Table -ModuleName ProgressReporter -Times 0
        Should -Invoke Format-List -ModuleName ProgressReporter -Times 0
        ($output | Where-Object { $_ -like '*Notes / Errors*' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -like '* - Archive is corrupt' }) | Should -Not -BeNullOrEmpty
    }

    It 'uses Format-List for narrow interactive consoles' {
        Mock Format-Table -ModuleName ProgressReporter { }
        Mock Format-List -ModuleName ProgressReporter { }

        Write-ExtractionSummary `
            -SourceDirectory 'C:\src' -DestinationDirectory 'C:\dest' `
            -ExtractMode 'Flat' -CollisionPolicy 'Rename' `
            -ZipCount 1 -ProcessedZips 1 -FilesExtracted 1 `
            -UncompressedBytes ([int64]1000) -CompressedBytes ([int64]0) `
            -MoveSummary $script:defaultMoveSummary -Errors $script:emptyErrors `
            -Elapsed $script:testElapsed -HostName 'ConsoleHost' -ConsoleWidth 80

        Should -Invoke Format-List -ModuleName ProgressReporter -Times 1
        Should -Invoke Format-Table -ModuleName ProgressReporter -Times 0
    }
}
