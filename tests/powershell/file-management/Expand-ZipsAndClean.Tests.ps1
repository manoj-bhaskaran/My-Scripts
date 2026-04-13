Set-StrictMode -Version Latest

Describe 'Expand-ZipsAndClean helper extraction refactor' {
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

        # Prepend using-namespace declarations so that short type aliases (e.g. [ZipFile],
        # [List[string]]) resolve when the helpers block is evaluated via Invoke-Expression.
        $usingLines = ($scriptText -split "`n" |
            Where-Object { $_ -match '^\s*using\s+namespace\s+' }) -join "`n"
        $helpersWithUsing = $usingLines + "`n" + $helpers

        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\Core\FileSystem\FileSystem.psm1') -Force

        function Write-LogDebug { param([string]$Message) }
        Invoke-Expression $helpersWithUsing
    }

    It 'defines mode-specific helper functions and dispatcher' {
        Get-Command Expand-ZipToSubfolder -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Expand-ZipFlat -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Expand-ZipSmart -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'dispatches PerArchiveSubfolder mode to Expand-ZipToSubfolder' {
        Mock Test-Path { $true }
        Mock Get-FullPath { '/tmp/dest' }
        Mock Get-SafeName { 'safe-name' }
        Mock Expand-ZipToSubfolder { 7 }
        Mock Expand-ZipFlat { 0 }

        $result = Expand-ZipSmart -ZipPath '/tmp/a.zip' -DestinationRoot '/tmp/dest' -ExtractMode PerArchiveSubfolder -SafeNameMaxLen 80

        $result | Should -Be 7
        Should -Invoke Expand-ZipToSubfolder -Times 1 -Exactly -ParameterFilter {
            $ZipPath -eq '/tmp/a.zip' -and
            $DestinationRoot -eq '/tmp/dest' -and
            $SafeSubfolderName -eq 'safe-name'
        }
        Should -Invoke Expand-ZipFlat -Times 0
    }

    It 'dispatches Flat mode to Expand-ZipFlat with computed destination root' {
        Mock Test-Path { $true }
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

    It 'blocks Zip Slip traversal entries in Flat mode' -Skip:(-not $IsWindows) {
        $root = Join-Path $TestDrive 'flat-zipslip'
        New-Item -ItemType Directory -Path $root -Force | Out-Null

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
        Test-Path -LiteralPath (Join-Path (Split-Path -Parent $root) 'evil.txt') | Should -BeFalse
    }
}
