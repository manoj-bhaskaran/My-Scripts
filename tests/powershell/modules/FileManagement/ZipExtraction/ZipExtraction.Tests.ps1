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
