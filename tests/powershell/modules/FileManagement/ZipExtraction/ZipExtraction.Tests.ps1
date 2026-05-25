Set-StrictMode -Version Latest

Describe 'Invoke-SingleZipExtraction' {
    BeforeAll {
        $moduleRoot = [System.IO.Path]::GetFullPath(
            (Join-Path $PSScriptRoot '..\..\..\..\..\src\powershell\modules'))

        Import-Module (Join-Path $moduleRoot 'Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $moduleRoot 'Core\Zip\Zip.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        # Dot-source private function directly (not exported by the module)
        . (Join-Path $moduleRoot 'FileManagement\ZipExtraction\Private\Invoke-SingleZipExtraction.ps1')
    }

    It 'returns FilesExtracted from Expand-ZipSmart when it returns an int' {
        $zipPath = Join-Path $TestDrive 'archive.zip'
        Set-Content -LiteralPath $zipPath -Value '' -NoNewline
        $zip = Get-Item -LiteralPath $zipPath

        Mock Get-ZipFileStats {
            return [pscustomobject]@{ FileCount = 3; UncompressedBytes = [int64]1500; CompressedBytes = [int64]800 }
        }
        Mock Expand-ZipSmart { return 3 }

        $result = Invoke-SingleZipExtraction -Zip $zip -DestDir '/fake/dest' -Mode 'Flat' -Policy 'Rename' -MaxLen 0

        $result.FilesExtracted    | Should -Be 3
        $result.UncompressedBytes | Should -Be 1500
        $result.CompressedBytes   | Should -Be 800
    }

    It 'falls back to stats.FileCount when Expand-ZipSmart returns a non-int' {
        $zipPath = Join-Path $TestDrive 'b.zip'
        Set-Content -LiteralPath $zipPath -Value '' -NoNewline
        $zip = Get-Item -LiteralPath $zipPath

        Mock Get-ZipFileStats {
            return [pscustomobject]@{ FileCount = 5; UncompressedBytes = [int64]2000; CompressedBytes = [int64]1000 }
        }
        Mock Expand-ZipSmart { return $null }

        $result = Invoke-SingleZipExtraction -Zip $zip -DestDir '/fake/dest' -Mode 'Flat' -Policy 'Rename' -MaxLen 0

        $result.FilesExtracted | Should -Be 5
    }

    It 'log message includes zip name and stats fields' {
        $zipPath = Join-Path $TestDrive 'logtest.zip'
        Set-Content -LiteralPath $zipPath -Value '' -NoNewline
        $zip = Get-Item -LiteralPath $zipPath

        Mock Get-ZipFileStats {
            return [pscustomobject]@{ FileCount = 2; UncompressedBytes = [int64]500; CompressedBytes = [int64]200 }
        }
        Mock Expand-ZipSmart { return 2 }

        $result = Invoke-SingleZipExtraction -Zip $zip -DestDir '/fake/dest' -Mode 'Flat' -Policy 'Rename' -MaxLen 0

        $result.Log | Should -BeLike '*logtest.zip*'
        $result.Log | Should -BeLike '*files=*'
        $result.Log | Should -BeLike '*uncompressed=*'
        $result.Log | Should -BeLike '*compressed=*'
    }

    It 'propagates exceptions thrown by inner functions' {
        $zipPath = Join-Path $TestDrive 'bad.zip'
        Set-Content -LiteralPath $zipPath -Value '' -NoNewline
        $zip = Get-Item -LiteralPath $zipPath

        Mock Get-ZipFileStats { throw 'Archive is corrupt' }

        { Invoke-SingleZipExtraction -Zip $zip -DestDir '/fake/dest' -Mode 'Flat' -Policy 'Rename' -MaxLen 0 } |
            Should -Throw '*corrupt*'
    }
}

Describe 'Invoke-ZipExtractions' {
    BeforeAll {
        $moduleRoot = [System.IO.Path]::GetFullPath(
            (Join-Path $PSScriptRoot '..\..\..\..\..\src\powershell\modules'))

        Import-Module (Join-Path $moduleRoot 'Core\FileSystem\FileSystem.psm1') -Force
        Import-Module (Join-Path $moduleRoot 'Core\Zip\Zip.psm1') -Force
        Import-Module (Join-Path $moduleRoot 'FileManagement\ZipExtraction\ZipExtraction.psm1') -Force
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
