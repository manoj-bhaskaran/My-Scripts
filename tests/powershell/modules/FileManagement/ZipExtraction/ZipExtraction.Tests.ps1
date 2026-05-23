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

    It 'returns correct file count and byte statistics for a valid archive' {
        $destDir = Join-Path $TestDrive 'ise-dest'
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null

        $zipPath = Join-Path $TestDrive 'sample.zip'
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry  = $archive.CreateEntry('file.txt')
            $stream = $entry.Open()
            $writer = New-Object System.IO.StreamWriter($stream)
            try { $writer.Write('hello world') } finally { $writer.Dispose() }
        } finally { $archive.Dispose() }

        $zip    = Get-Item -LiteralPath $zipPath
        # Use Flat mode: streams entries via ZipArchive directly, avoids Expand-Archive
        $result = Invoke-SingleZipExtraction -Zip $zip -DestDir $destDir -Mode 'Flat' -Policy 'Rename' -MaxLen 0

        $result.FilesExtracted    | Should -Be 1
        $result.UncompressedBytes | Should -BeGreaterThan 0
        $result.CompressedBytes   | Should -BeGreaterThan 0
    }

    It 'log message includes zip name, file count, and byte fields' {
        $destDir = Join-Path $TestDrive 'ise-log-dest'
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null

        $zipPath = Join-Path $TestDrive 'logtest.zip'
        $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry  = $archive.CreateEntry('a.txt')
            $stream = $entry.Open()
            $writer = New-Object System.IO.StreamWriter($stream)
            try { $writer.Write('data') } finally { $writer.Dispose() }
        } finally { $archive.Dispose() }

        $zip    = Get-Item -LiteralPath $zipPath
        $result = Invoke-SingleZipExtraction -Zip $zip -DestDir $destDir -Mode 'Flat' -Policy 'Rename' -MaxLen 0

        $result.Log | Should -BeLike "*logtest.zip*"
        $result.Log | Should -BeLike "*files=*"
        $result.Log | Should -BeLike "*uncompressed=*"
        $result.Log | Should -BeLike "*compressed=*"
    }

    It 'throws when the archive is corrupt' {
        $destDir = Join-Path $TestDrive 'ise-err-dest'
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null

        $badPath = Join-Path $TestDrive 'corrupt.zip'
        [System.IO.File]::WriteAllBytes($badPath, [byte[]](0xFF, 0xFE, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05))

        $zip = Get-Item -LiteralPath $badPath
        { Invoke-SingleZipExtraction -Zip $zip -DestDir $destDir -Mode 'Flat' -Policy 'Rename' -MaxLen 0 } |
            Should -Throw
    }
}
