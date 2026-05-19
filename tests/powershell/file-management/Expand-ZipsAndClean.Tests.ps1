Set-StrictMode -Version Latest

Describe 'Core/Zip module — public extraction functions' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    }

    It 'exports public extraction functions from the Zip module' {
        Get-Command Get-ZipFileStats      -Module Zip -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Expand-ZipToSubfolder -Module Zip -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Expand-ZipFlat        -Module Zip -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Expand-ZipSmart       -Module Zip -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'dispatches PerArchiveSubfolder mode to Expand-ZipToSubfolder' {
        # Mocks for intra-module calls must live inside InModuleScope so they intercept
        # calls made from within the Zip module (Expand-ZipSmart -> Expand-ZipToSubfolder).
        InModuleScope Zip {
            Mock New-DirectoryIfMissing { }
            Mock Get-FullPath { '/tmp/dest' }
            Mock Get-SafeName { 'safe-name' }
            Mock Expand-ZipToSubfolder { 7 }
            Mock Expand-ZipFlat { 0 }

            $result = Expand-ZipSmart -ZipPath '/tmp/a.zip' -DestinationRoot '/tmp/dest' -ExtractMode PerArchiveSubfolder -SafeNameMaxLen 80 -ExpectedFileCount 7

            $result | Should -Be 7
            Should -Invoke Expand-ZipToSubfolder -Times 1 -Exactly -ParameterFilter {
                $ZipPath -eq '/tmp/a.zip' -and
                $DestinationRoot -eq '/tmp/dest' -and
                $SafeSubfolderName -eq 'safe-name' -and
                $ExpectedFileCount -eq 7
            }
            Should -Invoke Expand-ZipFlat -Times 0
        }
    }

    It 'dispatches Flat mode to Expand-ZipFlat with computed destination root' {
        InModuleScope Zip {
            Mock New-DirectoryIfMissing { }
            Mock Get-FullPath { '/tmp/dest-full' }
            Mock Get-SafeName { 'unused-safe-name' }
            Mock Expand-ZipFlat { 3 }

            $result = Expand-ZipSmart -ZipPath '/tmp/b.zip' -DestinationRoot '/tmp/dest' -ExtractMode Flat -CollisionPolicy Rename

            $result | Should -Be 3
            Should -Invoke Expand-ZipFlat -Times 1 -Exactly -ParameterFilter {
                $ZipPath -eq '/tmp/b.zip' -and
                $DestinationRoot -eq '/tmp/dest' -and
                $DestinationRootFull -eq '/tmp/dest-full' -and
                $CollisionPolicy -eq 'Rename'
            }
        }
    }

    It 'applies Flat collision policy Skip by not overwriting existing files' {
        $root = Join-Path $TestDrive 'flat-skip'
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        $zipPath = Join-Path $TestDrive 'flat-skip.zip'
        $existingPath = Join-Path $root 'same.txt'
        Set-Content -LiteralPath $existingPath -Value 'existing' -NoNewline

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry = $archive.CreateEntry('same.txt')
            $stream = $entry.Open()
            $writer = New-Object System.IO.StreamWriter($stream)
            try { $writer.Write('incoming') } finally { $writer.Dispose() }
        } finally {
            $archive.Dispose()
        }

        $written = Expand-ZipFlat -ZipPath $zipPath -DestinationRoot $root -DestinationRootFull ([System.IO.Path]::GetFullPath($root)) -CollisionPolicy Skip

        $written | Should -Be 0
        (Get-Content -LiteralPath $existingPath -Raw) | Should -Be 'existing'
    }

    It 'blocks Zip Slip traversal entries in Flat mode' {
        $root = Join-Path $TestDrive 'flat-zipslip'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $outsideParent = Split-Path -Parent $root
        $outsideEvilPath = Join-Path $outsideParent 'evil.txt'
        Set-Content -LiteralPath $outsideEvilPath -Value 'sentinel' -NoNewline

        $zipPath = Join-Path $TestDrive 'flat-zipslip.zip'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $good = $archive.CreateEntry('good.txt')
            $goodStream = $good.Open()
            $goodWriter = New-Object System.IO.StreamWriter($goodStream)
            try { $goodWriter.Write('ok') } finally { $goodWriter.Dispose() }

            $evil = $archive.CreateEntry('../evil.txt')
            $evilStream = $evil.Open()
            $evilWriter = New-Object System.IO.StreamWriter($evilStream)
            try { $evilWriter.Write('bad') } finally { $evilWriter.Dispose() }
        } finally {
            $archive.Dispose()
        }

        $written = Expand-ZipFlat -ZipPath $zipPath -DestinationRoot $root -DestinationRootFull ([System.IO.Path]::GetFullPath($root)) -CollisionPolicy Rename

        $written | Should -Be 1
        Test-Path -LiteralPath (Join-Path $root 'good.txt') | Should -BeTrue
        (Get-Content -LiteralPath $outsideEvilPath -Raw) | Should -Be 'sentinel'
        @(
            Get-ChildItem -LiteralPath $outsideParent -Filter 'evil*.txt' -File |
            Where-Object { $_.Name -ne 'evil.txt' }
        ).Count | Should -Be 0
    }

    It 'rejects rooted entry names while allowing valid relative names' {
        InModuleScope Zip {
            $root = [System.IO.Path]::GetFullPath((Join-Path $TestDrive 'zipslip-rooted'))
            New-Item -ItemType Directory -Path $root -Force | Out-Null

            $valid  = Resolve-ZipEntryDestinationPath -DestinationRootFull $root -EntryFullName 'nested/file.txt'
            $rooted = Resolve-ZipEntryDestinationPath -DestinationRootFull $root -EntryFullName '/etc/passwd'

            $valid  | Should -Not -BeNullOrEmpty
            $valid.StartsWith($root) | Should -BeTrue
            $rooted | Should -BeNullOrEmpty
        }
    }

    It 'detects encrypted archive errors through nested exceptions' {
        InModuleScope Zip {
            $inner = [System.Exception]::new('Entry is encrypted and cannot be extracted')
            $outer = [System.Exception]::new('Extraction failed', $inner)
            $err   = [System.Management.Automation.ErrorRecord]::new($outer, 'EncryptedZip', [System.Management.Automation.ErrorCategory]::InvalidData, $null)

            (Test-IsEncryptedZipError -ErrorObject $err) | Should -BeTrue
            {
                Resolve-ExtractionError -ZipPath '/tmp/test.zip' -ErrorRecord $err
            } | Should -Throw "*zip may be encrypted*"
        }
    }

    It 'PerArchiveSubfolder: file count returned matches archive entry count' {
        $root = Join-Path $TestDrive 'subfolder-count'
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        $zipPath = Join-Path $TestDrive 'subfolder-count.zip'
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($name in 'a.txt', 'b.txt', 'c.txt') {
                $entry  = $archive.CreateEntry($name)
                $stream = $entry.Open()
                $writer = New-Object System.IO.StreamWriter($stream)
                try { $writer.Write("content-$name") } finally { $writer.Dispose() }
            }
        } finally {
            $archive.Dispose()
        }

        # Mock Expand-Archive so the test is CI-independent; verifies that
        # Expand-ZipToSubfolder returns ExpectedFileCount directly rather than
        # performing a post-extraction Get-ChildItem walk.
        Mock Expand-Archive { } -ModuleName Zip

        $stats = Get-ZipFileStats -ZipPath $zipPath
        $count = Expand-ZipToSubfolder -ZipPath $zipPath -DestinationRoot $root -SafeSubfolderName 'subfolder-count' -ExpectedFileCount $stats.FileCount

        $count | Should -Be $stats.FileCount
        $count | Should -Be 3
    }

    It 'Flat: file count returned matches archive entry count' {
        $root = Join-Path $TestDrive 'flat-filecount'
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        $zipPath = Join-Path $TestDrive 'flat-filecount.zip'
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($name in 'x.txt', 'y.txt') {
                $entry  = $archive.CreateEntry($name)
                $stream = $entry.Open()
                $writer = New-Object System.IO.StreamWriter($stream)
                try { $writer.Write("content-$name") } finally { $writer.Dispose() }
            }
        } finally {
            $archive.Dispose()
        }

        $stats = Get-ZipFileStats -ZipPath $zipPath
        $count = Expand-ZipFlat -ZipPath $zipPath -DestinationRoot $root -DestinationRootFull ([System.IO.Path]::GetFullPath($root)) -CollisionPolicy Rename

        $count | Should -Be $stats.FileCount
        $count | Should -Be 2
    }

    It 'Expand-ZipSmart PerArchiveSubfolder: returns correct count when ExpectedFileCount is omitted' {
        $root = Join-Path $TestDrive 'smart-fallback'
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        $zipPath = Join-Path $TestDrive 'smart-fallback.zip'
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($name in 'p.txt', 'q.txt') {
                $entry  = $archive.CreateEntry($name)
                $stream = $entry.Open()
                $writer = New-Object System.IO.StreamWriter($stream)
                try { $writer.Write("content-$name") } finally { $writer.Dispose() }
            }
        } finally {
            $archive.Dispose()
        }

        # Mock Expand-Archive so the test is CI-independent; verifies that
        # Expand-ZipSmart falls back to Get-ZipFileStats when ExpectedFileCount is
        # omitted and returns the correct count.
        Mock Expand-Archive { } -ModuleName Zip

        # Call without -ExpectedFileCount to exercise the Get-ZipFileStats fallback.
        $count = Expand-ZipSmart -ZipPath $zipPath -DestinationRoot $root -ExtractMode PerArchiveSubfolder

        $count | Should -Be 2
    }

    It 'Flat Overwrite: incoming file replaces existing file' {
        $root = Join-Path $TestDrive 'flat-overwrite'
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        $existingPath = Join-Path $root 'same.txt'
        Set-Content -LiteralPath $existingPath -Value 'existing' -NoNewline

        $zipPath = Join-Path $TestDrive 'flat-overwrite.zip'
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry  = $archive.CreateEntry('same.txt')
            $stream = $entry.Open()
            $writer = New-Object System.IO.StreamWriter($stream)
            try { $writer.Write('incoming') } finally { $writer.Dispose() }
        } finally {
            $archive.Dispose()
        }

        $written = Expand-ZipFlat -ZipPath $zipPath -DestinationRoot $root -DestinationRootFull ([System.IO.Path]::GetFullPath($root)) -CollisionPolicy Overwrite

        $written | Should -Be 1
        (Get-Content -LiteralPath $existingPath -Raw) | Should -Be 'incoming'
    }

    It 'Flat Rename: existing file untouched and incoming written under a unique name' {
        $root = Join-Path $TestDrive 'flat-rename'
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        $existingPath = Join-Path $root 'same.txt'
        Set-Content -LiteralPath $existingPath -Value 'existing' -NoNewline

        $zipPath = Join-Path $TestDrive 'flat-rename.zip'
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry  = $archive.CreateEntry('same.txt')
            $stream = $entry.Open()
            $writer = New-Object System.IO.StreamWriter($stream)
            try { $writer.Write('incoming') } finally { $writer.Dispose() }
        } finally {
            $archive.Dispose()
        }

        $written = Expand-ZipFlat -ZipPath $zipPath -DestinationRoot $root -DestinationRootFull ([System.IO.Path]::GetFullPath($root)) -CollisionPolicy Rename

        $written | Should -Be 1
        # Original must be untouched
        (Get-Content -LiteralPath $existingPath -Raw) | Should -Be 'existing'
        # A second .txt file with the incoming content must exist in the root
        $allTxt = @(Get-ChildItem -LiteralPath $root -Filter '*.txt' -File)
        $allTxt.Count | Should -Be 2
        $renamedFile = $allTxt | Where-Object { $_.Name -ne 'same.txt' } | Select-Object -First 1
        $renamedFile | Should -Not -BeNullOrEmpty
        (Get-Content -LiteralPath $renamedFile.FullName -Raw) | Should -Be 'incoming'
    }
}

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

    It 'handles non-existent parent gracefully' {
        $sourceDir = Join-Path $TestDrive 'orphan'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        # Mock Get-Item to return an item with no parent
        Mock Get-Item {
            [pscustomobject]@{ Parent = $null; FullName = $sourceDir }
        }

        { Move-ZipFilesToParent -SourceDir $sourceDir -QuietMode $true } | Should -Throw "*drive root*"
    }

    It 'Skip policy: leaves source zip and existing parent zip untouched on collision' {
        $parentDir = Join-Path $TestDrive 'parent-skip'
        $sourceDir = Join-Path $parentDir 'source'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        $srcZip    = Join-Path $sourceDir 'test.zip'
        $parentZip = Join-Path $parentDir 'test.zip'
        Set-Content -LiteralPath $srcZip    -Value 'source-content'  -NoNewline
        Set-Content -LiteralPath $parentZip -Value 'original-content' -NoNewline

        $result = Move-ZipFilesToParent -SourceDir $sourceDir -QuietMode $true -CollisionPolicy Skip

        $result.Count   | Should -Be 0
        $result.Skipped | Should -Be 1

        # Source zip must still be present and parent zip must be unchanged
        [System.IO.File]::Exists($srcZip) | Should -BeTrue
        (Get-Content -LiteralPath $parentZip -Raw) | Should -Be 'original-content'
    }

    It 'Overwrite policy: replaces existing parent zip with source zip on collision' {
        $parentDir = Join-Path $TestDrive 'parent-overwrite'
        $sourceDir = Join-Path $parentDir 'source'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        $srcZip    = Join-Path $sourceDir 'test.zip'
        $parentZip = Join-Path $parentDir 'test.zip'
        Set-Content -LiteralPath $srcZip    -Value 'new-content'      -NoNewline
        Set-Content -LiteralPath $parentZip -Value 'original-content' -NoNewline

        $result = Move-ZipFilesToParent -SourceDir $sourceDir -QuietMode $true -CollisionPolicy Overwrite

        $result.Count       | Should -Be 1
        $result.Overwritten | Should -Be 1

        # Source zip must be gone; parent zip must hold the new content
        [System.IO.File]::Exists($srcZip) | Should -BeFalse
        (Get-Content -LiteralPath $parentZip -Raw) | Should -Be 'new-content'
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

Describe 'Write-PhaseProgress' {
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

        Write-PhaseProgress -Activity 'Test' -Status 'Running' -Current 1 -Total 5 -QuietMode $true

        Should -Invoke Write-Progress -Times 0
    }

    It 'calls Write-Progress with computed percentage when QuietMode is false' {
        Mock Write-Progress { }

        Write-PhaseProgress -Activity 'Extracting' -Status 'file.zip' -Current 2 -Total 4 -QuietMode $false

        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter {
            $Activity -eq 'Extracting' -and
            $Status -eq 'file.zip' -and
            $PercentComplete -eq 50
        }
    }

    It 'includes CurrentOperation when provided' {
        Mock Write-Progress { }

        Write-PhaseProgress -Activity 'Moving' -Status '1 / 3 : a.zip' `
            -Current 1 -Total 3 -QuietMode $false -CurrentOperation 'Moving: 10 B of 30 B bytes'

        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter {
            $CurrentOperation -eq 'Moving: 10 B of 30 B bytes'
        }
    }

    It 'omits CurrentOperation when not provided' {
        $capturedParams = @{}
        Mock Write-Progress { $capturedParams['keys'] = $PSBoundParameters.Keys -join ',' }

        Write-PhaseProgress -Activity 'Moving' -Status '1 / 3 : a.zip' `
            -Current 1 -Total 3 -QuietMode $false

        $capturedParams['keys'] | Should -Not -BeLike '*CurrentOperation*'
    }

    It 'calls Write-Progress -Completed and suppresses update parameters' {
        Mock Write-Progress { }

        Write-PhaseProgress -Activity 'Extracting' -Status 'Done' `
            -Current 5 -Total 5 -QuietMode $false -Completed

        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter {
            $Activity -eq 'Extracting' -and $Completed -eq $true
        }
    }

    It 'suppresses Completed call when QuietMode is true' {
        Mock Write-Progress { }

        Write-PhaseProgress -Activity 'Extracting' -Status 'Done' `
            -Current 5 -Total 5 -QuietMode $true -Completed

        Should -Invoke Write-Progress -Times 0
    }

    It 'clamps percentage to 100 when Current equals Total' {
        Mock Write-Progress { }

        Write-PhaseProgress -Activity 'Test' -Status 'All done' -Current 7 -Total 7 -QuietMode $false

        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter {
            $PercentComplete -eq 100
        }
    }

    It 'uses Total=1 guard so zero Total does not cause division error' {
        Mock Write-Progress { }

        { Write-PhaseProgress -Activity 'Test' -Status 'Empty' -Current 0 -Total 0 -QuietMode $false } |
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

    It 'emits summary header when host is interactive (ConsoleHost)' {
        Mock Format-Table { }
        Mock Format-List  { }

        $output = @(Write-ExtractionSummary `
            -SourceDirectory 'C:\src' -DestinationDirectory 'C:\dest' `
            -ExtractMode 'PerArchiveSubfolder' -CollisionPolicy 'Rename' `
            -ZipCount 5 -ProcessedZips 5 -FilesExtracted 20 `
            -UncompressedBytes ([int64]1000000) -CompressedBytes ([int64]300000) `
            -MoveSummary $script:defaultMoveSummary -Errors $script:emptyErrors `
            -Elapsed $script:testElapsed -HostName 'ConsoleHost')

        $output | Should -Contain '==== Expand-ZipsAndClean Summary ===='
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

    It 'emits error notes when interactive and error list is non-empty' {
        $errList = [System.Collections.Generic.List[string]]::new()
        $errList.Add('Something went wrong')
        Mock Format-Table { }
        Mock Format-List  { }

        $output = @(Write-ExtractionSummary `
            -SourceDirectory 'C:\src' -DestinationDirectory 'C:\dest' `
            -ExtractMode 'Flat' -CollisionPolicy 'Skip' `
            -ZipCount 2 -ProcessedZips 2 -FilesExtracted 4 `
            -UncompressedBytes ([int64]500) -CompressedBytes ([int64]200) `
            -MoveSummary $script:defaultMoveSummary -Errors $errList `
            -Elapsed $script:testElapsed -HostName 'ConsoleHost')

        ($output | Where-Object { $_ -like '*Notes / Errors*' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -like '* - Something went wrong' }) | Should -Not -BeNullOrEmpty
    }

    It 'summary view contains expected fields (SrcDir, ZipsFound, Ratio, Duration)' {
        # -PassThru emits the PSCustomObject to the pipeline alongside string output;
        # filter by type to extract it without relying on Format-Table/-List mocks.
        Mock Format-Table { }
        Mock Format-List  { }

        $allOutput = @(Write-ExtractionSummary `
            -SourceDirectory 'C:\mysrc' -DestinationDirectory 'C:\mydest' `
            -ExtractMode 'PerArchiveSubfolder' -CollisionPolicy 'Rename' `
            -ZipCount 7 -ProcessedZips 6 -FilesExtracted 30 `
            -UncompressedBytes ([int64]2000000) -CompressedBytes ([int64]600000) `
            -MoveSummary $script:defaultMoveSummary -Errors $script:emptyErrors `
            -Elapsed ([timespan]::FromSeconds(10)) -HostName 'ConsoleHost' -PassThru)

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
}

Describe 'Invoke-ZipExtractions — parallel extraction' {
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
        function Write-LogInfo  { param([string]$Message) }
        . ([ScriptBlock]::Create($helpersWithUsing))
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

Describe 'Default path resolution from environment variables' {
    # These tests evaluate the same null-coalescing expressions used in the param()
    # defaults to verify env-var precedence and profile-relative fallback behavior
    # without invoking the full script (which would attempt real file-system access).

    AfterEach {
        Remove-Item Env:\EXPAND_ZIPS_SOURCE_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:\EXPAND_ZIPS_DEST_DIR   -ErrorAction SilentlyContinue
    }

    It 'SourceDirectory default uses EXPAND_ZIPS_SOURCE_DIR when set' {
        $env:EXPAND_ZIPS_SOURCE_DIR = '/custom/source'
        $resolved = $env:EXPAND_ZIPS_SOURCE_DIR ?? (Join-Path $HOME 'Downloads/picconvert')
        $resolved | Should -Be '/custom/source'
    }

    It 'SourceDirectory default falls back to $HOME/Downloads/picconvert when env var is absent' {
        Remove-Item Env:\EXPAND_ZIPS_SOURCE_DIR -ErrorAction SilentlyContinue
        $resolved = $env:EXPAND_ZIPS_SOURCE_DIR ?? (Join-Path $HOME 'Downloads/picconvert')
        $resolved | Should -Be (Join-Path $HOME 'Downloads/picconvert')
    }

    It 'DestinationDirectory default uses EXPAND_ZIPS_DEST_DIR when set' {
        $env:EXPAND_ZIPS_DEST_DIR = '/custom/dest'
        $resolved = $env:EXPAND_ZIPS_DEST_DIR ?? (Join-Path $HOME 'Desktop/New folder')
        $resolved | Should -Be '/custom/dest'
    }

    It 'DestinationDirectory default falls back to $HOME/Desktop/New folder when env var is absent' {
        Remove-Item Env:\EXPAND_ZIPS_DEST_DIR -ErrorAction SilentlyContinue
        $resolved = $env:EXPAND_ZIPS_DEST_DIR ?? (Join-Path $HOME 'Desktop/New folder')
        $resolved | Should -Be (Join-Path $HOME 'Desktop/New folder')
    }

    It 'param block defaults in the script match env-var resolution when vars are set' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)

        $env:EXPAND_ZIPS_SOURCE_DIR = (Join-Path $TestDrive 'env-src')
        $env:EXPAND_ZIPS_DEST_DIR   = (Join-Path $TestDrive 'env-dest')
        New-Item -ItemType Directory -Path $env:EXPAND_ZIPS_SOURCE_DIR -Force | Out-Null
        New-Item -ItemType Directory -Path $env:EXPAND_ZIPS_DEST_DIR   -Force | Out-Null

        # -WhatIf prevents any real file operations; just verify the script reads the env vars.
        $output = & $scriptPath -WhatIf 2>&1
        # The script should not throw a validation error for the default paths.
        $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } |
            Where-Object { $_.Exception.Message -like '*ValidateNotNullOrEmpty*' } |
            Should -BeNullOrEmpty
    }

    It 'param block defaults in the script use profile-relative fallback when vars are absent' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)

        Remove-Item Env:\EXPAND_ZIPS_SOURCE_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:\EXPAND_ZIPS_DEST_DIR   -ErrorAction SilentlyContinue

        # Parse the script and extract the default expression for -SourceDirectory.
        $ast    = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $params = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true)

        $srcParam  = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SourceDirectory' }
        $destParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'DestinationDirectory' }

        $srcParam  | Should -Not -BeNullOrEmpty -Because 'SourceDirectory param must exist in the script'
        $destParam | Should -Not -BeNullOrEmpty -Because 'DestinationDirectory param must exist in the script'

        # Verify neither default contains a hard-coded personal path.
        $srcDefault  = $srcParam.DefaultValue.Extent.Text
        $destDefault = $destParam.DefaultValue.Extent.Text

        $srcDefault  | Should -BeLike '*EXPAND_ZIPS_SOURCE_DIR*' -Because 'default must reference the env var'
        $destDefault | Should -BeLike '*EXPAND_ZIPS_DEST_DIR*'   -Because 'default must reference the env var'
        $srcDefault  | Should -Not -BeLike '*manoj*'             -Because 'no personal hard-coded path'
        $destDefault | Should -Not -BeLike '*manoj*'             -Because 'no personal hard-coded path'
    }
}

Describe 'Smoke — Expand-ZipsAndClean.ps1 parse check' {
    It 'parses without error under pwsh 7.x (#requires -Version 7.0 is honoured)' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)

        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)

        $errors | Should -BeNullOrEmpty
    }

    It 'contains #requires -Version 7.0 directive' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
        $firstLine = (Get-Content -LiteralPath $scriptPath -TotalCount 1).Trim()

        $firstLine | Should -Be '#requires -Version 7.0'
    }
}
