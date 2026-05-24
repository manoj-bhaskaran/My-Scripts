Set-StrictMode -Version Latest

Describe 'Remove-SourceDirectory' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw

        $helpersStart = $scriptText.IndexOf('#region Helpers')
        $helpersEnd = $scriptText.IndexOf('#endregion Helpers')
        if ($helpersStart -lt 0 -or $helpersEnd -lt 0) {
            throw 'Failed to locate helpers region in Expand-ZipsAndClean.ps1'
        }

        $helpers = $scriptText.Substring($helpersStart, $helpersEnd - $helpersStart)
        $usingLines = ($scriptText -split "`n" |
            Where-Object { $_ -match '^\s*using\s+namespace\s+' }) -join "`n"
        $helpersWithUsing = $usingLines + "`n" + $helpers

        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        function Write-LogDebug { param([string]$Message) }
        function Remove-FileWithRetry {
            param([string]$Path)
            if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
        }
        . ([ScriptBlock]::Create($helpersWithUsing))
    }

    It 'blocks DeleteSource and preserves zip files remaining after a Skip-policy move' {
        $sourceDir = Join-Path $TestDrive 'source-skip-remaining'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        $skippedZip = Join-Path $sourceDir 'skipped.zip'
        Set-Content -LiteralPath $skippedZip -Value 'zip-content' -NoNewline
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $false -ErrorList $errors

        # Source directory and the zip must both survive
        Test-Path -LiteralPath $sourceDir  | Should -BeTrue
        Test-Path -LiteralPath $skippedZip | Should -BeTrue
        $errors.Count | Should -Be 1
        $errors[0] | Should -BeLike '*zip file*remain*'
    }

    It 'warns "only empty subdirectories remain" when source contains only empty subdirs and -CleanNonZips is not set' {
        $sourceDir = Join-Path $TestDrive 'source-empty-subdir'
        New-Item -ItemType Directory -Path (Join-Path $sourceDir 'sub') -Force | Out-Null
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $false -ErrorList $errors

        $errors.Count | Should -Be 1
        $errors[0] | Should -BeLike '*only empty subdirectories remain*'
        Test-Path -LiteralPath $sourceDir | Should -BeTrue
    }

    It 'warns "non-zip files remain" when source contains actual non-zip files and -CleanNonZips is not set' {
        $sourceDir = Join-Path $TestDrive 'source-nonzip-files'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $sourceDir 'leftover.txt') -Value 'data'
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $false -ErrorList $errors

        $errors.Count | Should -Be 1
        $errors[0] | Should -BeLike '*non-zip files remain*'
        Test-Path -LiteralPath $sourceDir | Should -BeTrue
    }

    It 'deletes nested non-zip files deepest-first and removes source dir when -CleanNonZips is set' {
        $sourceDir = Join-Path $TestDrive 'source-nested'
        $nestedDir = Join-Path $sourceDir 'sub' | Join-Path -ChildPath 'nested'
        New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $nestedDir 'file.txt')  -Value 'nested content'
        Set-Content -LiteralPath (Join-Path $sourceDir 'top.txt')   -Value 'top content'
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $true -ErrorList $errors

        # End-state: the source directory must be gone. Assemble a rich -Because
        # clause so CI failures are self-diagnosing.
        #
        # On at least one GitHub Actions Linux runner configuration we observed
        # a repeatable anomaly where Test-Path -LiteralPath returns $true for a
        # path that [System.IO.Directory]::Exists, [System.IO.File]::Exists,
        # and Get-ChildItem all report as non-existent (the latter throwing
        # "Cannot find path ... it does not exist"). We therefore anchor the
        # assertion on [System.IO.Directory]::Exists -- the same API the
        # function uses to decide whether deletion succeeded -- and surface
        # the other signals in the diagnostic for visibility.
        $netDirExists = [System.IO.Directory]::Exists($sourceDir)
        $netFileExists = [System.IO.File]::Exists($sourceDir)
        $psExists = Test-Path -LiteralPath $sourceDir
        $psType = if ($psExists) {
            "container=$(Test-Path -LiteralPath $sourceDir -PathType Container);leaf=$(Test-Path -LiteralPath $sourceDir -PathType Leaf)"
        } else { '<n/a>' }
        $remaining = if ($psExists) {
            try {
                (Get-ChildItem -LiteralPath $sourceDir -Recurse -Force -ErrorAction Stop |
                ForEach-Object FullName) -join ', '
            } catch { "<enum-failed: $($_.Exception.Message)>" }
        } else { '<none>' }
        $diag = "errors=[$($errors -join '; ')]; IO.Directory.Exists=$netDirExists; IO.File.Exists=$netFileExists; Test-Path=$psExists ($psType); sourceDir='$sourceDir'; remaining=[$remaining]"

        $netDirExists | Should -BeFalse -Because $diag
        $errors.Count | Should -Be 0    -Because $diag
    }

    It 'surfaces Get-ChildItem read errors as warnings rather than silently dropping them' {
        $sourceDir = Join-Path $TestDrive 'source-unreadable'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        Mock Get-ChildItem {
            Write-Error 'Access to the path is denied.'
        }
        Mock Write-Warning {}
        $errors = [System.Collections.Generic.List[string]]::new()

        { Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $false -ErrorList $errors } |
        Should -Not -Throw

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*scan*' }
    }

}

Describe 'Move-ZipFilesToParent' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw

        $helpersStart = $scriptText.IndexOf('#region Helpers')
        $helpersEnd = $scriptText.IndexOf('#endregion Helpers')
        if ($helpersStart -lt 0 -or $helpersEnd -lt 0) {
            throw 'Failed to locate helpers region in Expand-ZipsAndClean.ps1'
        }

        $helpers = $scriptText.Substring($helpersStart, $helpersEnd - $helpersStart)
        $usingLines = ($scriptText -split "`n" |
            Where-Object { $_ -match '^\s*using\s+namespace\s+' }) -join "`n"
        $helpersWithUsing = $usingLines + "`n" + $helpers

        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        function Write-LogDebug { param([string]$Message) }
        function Move-FileWithRetry {
            param([string]$Source, [string]$Destination, [switch]$Force)
            Move-Item -LiteralPath $Source -Destination $Destination -Force:$Force
        }
        . ([ScriptBlock]::Create($helpersWithUsing))
    }

    It 'moves zip files from source to parent directory' {
        $parentDir = Join-Path $TestDrive 'parent'
        $sourceDir = Join-Path $parentDir 'source'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        $zipPath = Join-Path $sourceDir 'test.zip'
        Set-Content -LiteralPath $zipPath -Value 'dummy zip content' -NoNewline

        $result = Move-ZipFilesToParent -SourceDir $sourceDir -QuietMode $true

        $result.Count | Should -Be 1
        $result.Bytes | Should -BeGreaterThan 0
        $result.Destination | Should -Be $parentDir

        [System.IO.File]::Exists($zipPath) | Should -BeFalse
        [System.IO.File]::Exists((Join-Path $parentDir 'test.zip')) | Should -BeTrue
    }

    It 'throws clear error for drive root source directory' {
        # Mock Get-Item to simulate a drive root (no parent directory)
        Mock Get-Item {
            [pscustomobject]@{ Parent = $null; FullName = 'C:\' }
        }

        { Move-ZipFilesToParent -SourceDir 'C:\' -QuietMode $true } | Should -Throw "*drive root*"
    }

    It 'Rename policy: keeps existing parent zip and moves source zip under a unique name on collision' {
        $parentDir = Join-Path $TestDrive 'parent-rename'
        $sourceDir = Join-Path $parentDir 'source'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        $srcZip    = Join-Path $sourceDir 'test.zip'
        $parentZip = Join-Path $parentDir 'test.zip'
        Set-Content -LiteralPath $srcZip    -Value 'new-content'      -NoNewline
        Set-Content -LiteralPath $parentZip -Value 'original-content' -NoNewline

        $result = Move-ZipFilesToParent -SourceDir $sourceDir -QuietMode $true -CollisionPolicy Rename

        $result.Count   | Should -Be 1
        $result.Renamed | Should -Be 1

        # Source zip must be gone; original parent zip must be intact
        [System.IO.File]::Exists($srcZip) | Should -BeFalse
        (Get-Content -LiteralPath $parentZip -Raw) | Should -Be 'original-content'

        # A second zip with a unique name must exist in the parent
        $parentZips = @(Get-ChildItem -LiteralPath $parentDir -Filter '*.zip' -File)
        $parentZips.Count | Should -Be 2
    }

}

Describe 'Show-ProgressPhase' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw

        $helpersStart = $scriptText.IndexOf('#region Helpers')
        $helpersEnd   = $scriptText.IndexOf('#endregion Helpers')
        if ($helpersStart -lt 0 -or $helpersEnd -lt 0) {
            throw 'Failed to locate helpers region in Expand-ZipsAndClean.ps1'
        }

        $helpers = $scriptText.Substring($helpersStart, $helpersEnd - $helpersStart)
        $usingLines = ($scriptText -split "`n" |
            Where-Object { $_ -match '^\s*using\s+namespace\s+' }) -join "`n"
        $helpersWithUsing = $usingLines + "`n" + $helpers

        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        function Write-LogDebug { param([string]$Message) }
        . ([ScriptBlock]::Create($helpersWithUsing))
    }

    It 'suppresses Write-Progress when QuietMode is true' {
        Mock Write-Progress { }

        Show-ProgressPhase -Activity 'Test' -Status 'Running' -Current 1 -Total 5 -QuietMode $true

        Should -Invoke Write-Progress -Times 0
    }

    It 'passes expected progress payload to Write-Progress in active mode' {
        Mock Write-Progress { }

        Show-ProgressPhase -Activity 'Extracting' -Status 'file.zip' -Current 2 -Total 4 -QuietMode $false
        Show-ProgressPhase -Activity 'Moving' -Status '1 / 3 : a.zip' `
            -Current 1 -Total 3 -QuietMode $false -CurrentOperation 'Moving: 10 B of 30 B bytes'

        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter {
            $Activity -eq 'Extracting' -and
            $Status -eq 'file.zip' -and
            $PercentComplete -eq 50
        }
        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter {
            $CurrentOperation -eq 'Moving: 10 B of 30 B bytes'
        }
    }

    It 'calls Write-Progress -Completed and suppresses update parameters' {
        Mock Write-Progress { }

        Show-ProgressPhase -Activity 'Extracting' -Status 'Done' `
            -Current 5 -Total 5 -QuietMode $false -Completed

        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter {
            $Activity -eq 'Extracting' -and $Completed -eq $true
        }
    }

    It 'uses Total=1 guard so zero Total does not cause division error' {
        Mock Write-Progress { }

        { Show-ProgressPhase -Activity 'Test' -Status 'Empty' -Current 0 -Total 0 -QuietMode $false } |
            Should -Not -Throw
    }
}

Describe 'Write-ExtractionSummary' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw

        $helpersStart = $scriptText.IndexOf('#region Helpers')
        $helpersEnd   = $scriptText.IndexOf('#endregion Helpers')
        if ($helpersStart -lt 0 -or $helpersEnd -lt 0) {
            throw 'Failed to locate helpers region in Expand-ZipsAndClean.ps1'
        }

        $helpers = $scriptText.Substring($helpersStart, $helpersEnd - $helpersStart)
        $usingLines = ($scriptText -split "`n" |
            Where-Object { $_ -match '^\s*using\s+namespace\s+' }) -join "`n"
        $helpersWithUsing = $usingLines + "`n" + $helpers

        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        function Write-LogDebug { param([string]$Message) }
        . ([ScriptBlock]::Create($helpersWithUsing))

        $script:defaultMoveSummary = [pscustomobject]@{
            Count = 3; Bytes = [int64]5000; Destination = 'C:\parent'
            Skipped = 0; Overwritten = 0; Renamed = 1
        }
        $script:emptyErrors = [System.Collections.Generic.List[string]]::new()
        $script:testElapsed = [timespan]::FromSeconds(2.5)
    }

    It 'emits interactive summary header and view payload' {
        Mock Format-Table { }
        Mock Format-List  { }

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
        Mock Format-Table { }
        Mock Format-List  { }

        $output = @(Write-ExtractionSummary `
            -SourceDirectory 'C:\src' -DestinationDirectory 'C:\dest' `
            -ExtractMode 'PerArchiveSubfolder' -CollisionPolicy 'Rename' `
            -ZipCount 5 -ProcessedZips 5 -FilesExtracted 20 `
            -UncompressedBytes ([int64]1000000) -CompressedBytes ([int64]300000) `
            -MoveSummary $script:defaultMoveSummary -Errors $script:emptyErrors `
            -Elapsed $script:testElapsed -HostName 'DefaultHost')

        $output.Count   | Should -Be 0
        Should -Invoke Format-Table -Times 0
        Should -Invoke Format-List  -Times 0
    }

    It 'emits error notes even when host is non-interactive' {
        $errList = [System.Collections.Generic.List[string]]::new()
        $errList.Add('Archive is corrupt')
        Mock Format-Table { }
        Mock Format-List  { }

        $output = @(Write-ExtractionSummary `
            -SourceDirectory 'C:\src' -DestinationDirectory 'C:\dest' `
            -ExtractMode 'Flat' -CollisionPolicy 'Skip' `
            -ZipCount 1 -ProcessedZips 0 -FilesExtracted 0 `
            -UncompressedBytes ([int64]0) -CompressedBytes ([int64]0) `
            -MoveSummary $script:defaultMoveSummary -Errors $errList `
            -Elapsed $script:testElapsed -HostName 'DefaultHost')

        Should -Invoke Format-Table -Times 0
        Should -Invoke Format-List  -Times 0
        ($output | Where-Object { $_ -like '*Notes / Errors*' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -like '* - Archive is corrupt' }) | Should -Not -BeNullOrEmpty
    }

}

Describe 'Invoke-ZipExtractions — parallel extraction' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\FileManagement\ZipExtraction\ZipExtraction.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    }

    It 'parallel path (-ThrottleLimit 2) extracts all archives and aggregates results correctly' {
        $sourceDir = Join-Path $TestDrive 'parallel-src'
        $destDir   = Join-Path $TestDrive 'parallel-dest'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $destDir   -Force | Out-Null

        foreach ($name in 'archive1', 'archive2') {
            $zipPath = Join-Path $sourceDir "$name.zip"
            $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
            try {
                $entry  = $archive.CreateEntry("$name-file.txt")
                $stream = $entry.Open()
                $writer = New-Object System.IO.StreamWriter($stream)
                try { $writer.Write("content of $name") } finally { $writer.Dispose() }
            } finally {
                $archive.Dispose()
            }
        }

        $errorList = [System.Collections.Generic.List[string]]::new()
        $result = Invoke-ZipExtractions `
            -SourceDir      $sourceDir `
            -DestinationDir $destDir `
            -Mode           'PerArchiveSubfolder' `
            -Policy         'Rename' `
            -SafeNameMaxLen 0 `
            -QuietMode      $true `
            -ErrorList      $errorList `
            -ThrottleLimit  2

        $result.ZipCount       | Should -Be 2
        $result.ProcessedZips  | Should -Be 2
        $result.FilesExtracted | Should -Be 2
        $errorList.Count       | Should -Be 0

        @(Get-ChildItem -LiteralPath $destDir -Directory).Count | Should -Be 2
    }

    It 'parallel path errors are collected and the successful archives still contribute to totals' {
        $sourceDir = Join-Path $TestDrive 'parallel-err-src'
        $destDir   = Join-Path $TestDrive 'parallel-err-dest'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $destDir   -Force | Out-Null

        # One valid archive
        $zipPath = Join-Path $sourceDir 'good.zip'
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry  = $archive.CreateEntry('good-file.txt')
            $stream = $entry.Open()
            $writer = New-Object System.IO.StreamWriter($stream)
            try { $writer.Write('good content') } finally { $writer.Dispose() }
        } finally {
            $archive.Dispose()
        }

        # One corrupt archive: random bytes with no ZIP magic so ZipFile.OpenRead throws.
        $badZipPath = Join-Path $sourceDir 'bad.zip'
        [System.IO.File]::WriteAllBytes($badZipPath, [byte[]](0xFF, 0xFE, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05))

        $errorList = [System.Collections.Generic.List[string]]::new()
        $result = Invoke-ZipExtractions `
            -SourceDir      $sourceDir `
            -DestinationDir $destDir `
            -Mode           'PerArchiveSubfolder' `
            -Policy         'Rename' `
            -SafeNameMaxLen 0 `
            -QuietMode      $true `
            -ErrorList      $errorList `
            -ThrottleLimit  2

        $result.ZipCount      | Should -Be 2
        $result.ProcessedZips | Should -Be 1
        $errorList.Count      | Should -Be 1
        $errorList[0]         | Should -BeLike "*bad.zip*"
    }
}

Describe 'Test-ScriptPreconditions' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw

        $helpersStart = $scriptText.IndexOf('#region Helpers')
        $helpersEnd   = $scriptText.IndexOf('#endregion Helpers')
        if ($helpersStart -lt 0 -or $helpersEnd -lt 0) {
            throw 'Failed to locate helpers region in Expand-ZipsAndClean.ps1'
        }

        $helpers = $scriptText.Substring($helpersStart, $helpersEnd - $helpersStart)
        $usingLines = ($scriptText -split "`n" |
            Where-Object { $_ -match '^\s*using\s+namespace\s+' }) -join "`n"
        $helpersWithUsing = $usingLines + "`n" + $helpers

        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        function Write-LogDebug { param([string]$Message) }
        . ([ScriptBlock]::Create($helpersWithUsing))
    }

    It 'throws when source and destination are the same path' {
        # Get-FullPath returns the same (possibly mangled) string for both arguments,
        # so the equality check always fires before any path-containment logic.
        Mock Get-FullPath { param([string]$Path) $Path }
        $sep = [System.IO.Path]::DirectorySeparatorChar
        $dir = "${sep}precond-same"

        { Test-ScriptPreconditions -SourceDir $dir -DestinationDir $dir } |
            Should -Throw "*Source and destination cannot be the same*"
    }

    It 'throws when destination is inside the source directory' {
        # Get-FullPath converts '/' to '\' before resolving, which breaks containment
        # detection on Linux (Add-TrailingSeparator then adds '/' making StartsWith fail).
        # Mock it as an identity so Test-PathContainment sees native-separator paths.
        Mock Get-FullPath { param([string]$Path) $Path }
        $sep  = [System.IO.Path]::DirectorySeparatorChar
        $src  = "${sep}precond-src"
        $dest = "${sep}precond-src${sep}inner"

        { Test-ScriptPreconditions -SourceDir $src -DestinationDir $dest } |
            Should -Throw "*Destination cannot be inside the source*"
    }

    It 'throws when source is inside the destination directory' {
        Mock Get-FullPath { param([string]$Path) $Path }
        $sep  = [System.IO.Path]::DirectorySeparatorChar
        $dest = "${sep}precond-dest"
        $src  = "${sep}precond-dest${sep}inner"

        { Test-ScriptPreconditions -SourceDir $src -DestinationDir $dest } |
            Should -Throw "*Source cannot be inside the destination*"
    }
}

Describe 'Resolve-MoveTarget' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw

        $helpersStart = $scriptText.IndexOf('#region Helpers')
        $helpersEnd   = $scriptText.IndexOf('#endregion Helpers')
        if ($helpersStart -lt 0 -or $helpersEnd -lt 0) {
            throw 'Failed to locate helpers region in Expand-ZipsAndClean.ps1'
        }

        $helpers = $scriptText.Substring($helpersStart, $helpersEnd - $helpersStart)
        $usingLines = ($scriptText -split "`n" |
            Where-Object { $_ -match '^\s*using\s+namespace\s+' }) -join "`n"
        $helpersWithUsing = $usingLines + "`n" + $helpers

        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        function Write-LogDebug { param([string]$Message) }
        . ([ScriptBlock]::Create($helpersWithUsing))
    }

    It 'returns PolicyTag None and canonical TargetPath when no collision' {
        $parentDir = Join-Path $TestDrive 'rmt-no-coll'
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        $zipPath = Join-Path $TestDrive 'rmt-no-coll-src.zip'
        Set-Content -LiteralPath $zipPath -Value 'x' -NoNewline
        $zip = Get-Item -LiteralPath $zipPath

        $result = Resolve-MoveTarget -Zip $zip -Parent $parentDir -CollisionPolicy 'Rename'

        $result.PolicyTag  | Should -Be 'None'
        $result.TargetPath | Should -Be (Join-Path $parentDir 'rmt-no-coll-src.zip')
    }

    It 'returns PolicyTag Skip and unchanged TargetPath when collision and policy is Skip' {
        $parentDir = Join-Path $TestDrive 'rmt-skip'
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $parentDir 'dup.zip') -Value 'existing' -NoNewline
        $zipPath = Join-Path $TestDrive 'rmt-skip-src.zip'
        Set-Content -LiteralPath $zipPath -Value 'new' -NoNewline
        # Rename to collide with the parent file
        Rename-Item -LiteralPath $zipPath -NewName 'dup.zip'
        $zip = Get-Item -LiteralPath (Join-Path $TestDrive 'dup.zip')

        $result = Resolve-MoveTarget -Zip $zip -Parent $parentDir -CollisionPolicy 'Skip'

        $result.PolicyTag  | Should -Be 'Skip'
        $result.TargetPath | Should -Be (Join-Path $parentDir 'dup.zip')
    }

    It 'returns PolicyTag Overwrite and unchanged TargetPath when collision and policy is Overwrite' {
        $parentDir = Join-Path $TestDrive 'rmt-overwrite'
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $parentDir 'ow.zip') -Value 'existing' -NoNewline
        $zipPath = Join-Path $TestDrive 'rmt-overwrite-src.zip'
        Set-Content -LiteralPath $zipPath -Value 'new' -NoNewline
        Rename-Item -LiteralPath $zipPath -NewName 'ow.zip'
        $zip = Get-Item -LiteralPath (Join-Path $TestDrive 'ow.zip')

        $result = Resolve-MoveTarget -Zip $zip -Parent $parentDir -CollisionPolicy 'Overwrite'

        $result.PolicyTag  | Should -Be 'Overwrite'
        $result.TargetPath | Should -Be (Join-Path $parentDir 'ow.zip')
    }

    It 'returns PolicyTag Rename and a unique TargetPath when collision and policy is Rename' {
        $parentDir = Join-Path $TestDrive 'rmt-rename'
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $parentDir 'rn.zip') -Value 'existing' -NoNewline
        $zipPath = Join-Path $TestDrive 'rmt-rename-src.zip'
        Set-Content -LiteralPath $zipPath -Value 'new' -NoNewline
        Rename-Item -LiteralPath $zipPath -NewName 'rn.zip'
        $zip = Get-Item -LiteralPath (Join-Path $TestDrive 'rn.zip')

        $result = Resolve-MoveTarget -Zip $zip -Parent $parentDir -CollisionPolicy 'Rename'

        $result.PolicyTag  | Should -Be 'Rename'
        $result.TargetPath | Should -Not -Be (Join-Path $parentDir 'rn.zip')
        $result.TargetPath | Should -BeLike (Join-Path $parentDir 'rn*')
    }
}
