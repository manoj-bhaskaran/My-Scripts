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

        function Write-LogDebug { param([string]$Message) }
        Invoke-Expression $helpersWithUsing
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

        function Write-LogDebug { param([string]$Message) }
        Invoke-Expression $helpersWithUsing
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

        Test-Path -LiteralPath $zipPath | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $parentDir 'test.zip') | Should -BeTrue
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
}
