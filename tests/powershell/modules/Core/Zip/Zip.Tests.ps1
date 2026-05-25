Set-StrictMode -Version Latest

Describe 'Core/Zip module — public extraction functions' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '..\..\..\..\..\src\powershell\modules\Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
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

    It 'Flat Overwrite: incoming file replaces existing file (routed through Expand-ZipSmart)' {
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

        # Route through Expand-ZipSmart to cover Flat-mode dispatch with real behaviour.
        $written = Expand-ZipSmart -ZipPath $zipPath -DestinationRoot $root -ExtractMode Flat -CollisionPolicy Overwrite

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
