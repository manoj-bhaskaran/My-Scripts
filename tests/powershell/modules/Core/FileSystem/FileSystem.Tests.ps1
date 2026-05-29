Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Helper: resolve paths relative to this test file
# ---------------------------------------------------------------------------

$Script:fsRoot     = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\src\powershell\modules\Core\FileSystem'))
$Script:modulePath = Join-Path $Script:fsRoot 'FileSystem.psm1'
$Script:privPath   = Join-Path $Script:fsRoot 'Private'

# ---------------------------------------------------------------------------
# Public function tests — call through the exported surface
# ---------------------------------------------------------------------------

Describe 'Remove-SourceDirectory' {
    BeforeAll {
        Import-Module $Script:modulePath -Force
    }

    It 'blocks DeleteSource and preserves zip files remaining after a Skip-policy move' {
        $sourceDir = Join-Path $TestDrive 'source-skip-remaining'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        $skippedZip = Join-Path $sourceDir 'skipped.zip'
        Set-Content -LiteralPath $skippedZip -Value 'zip-content' -NoNewline
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $false -ErrorList $errors

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

        # Anchor on [System.IO.Directory]::Exists — same API the function uses to decide
        # success. On some GitHub Actions Linux runners, Test-Path can transiently return
        # $true for a path that the .NET APIs report as gone.
        $netDirExists = [System.IO.Directory]::Exists($sourceDir)
        $psExists     = Test-Path -LiteralPath $sourceDir
        $remaining    = if ($psExists) {
            try { (Get-ChildItem -LiteralPath $sourceDir -Recurse -Force -ErrorAction Stop | ForEach-Object FullName) -join ', ' }
            catch { "<enum-failed: $($_.Exception.Message)>" }
        } else { '<none>' }
        $diag = "errors=[$($errors -join '; ')]; IO.Directory.Exists=$netDirExists; Test-Path=$psExists; remaining=[$remaining]"

        $netDirExists | Should -BeFalse -Because $diag
        $errors.Count | Should -Be 0    -Because $diag
    }

    It 'deletes an already-empty source directory without error' {
        $sourceDir = Join-Path $TestDrive 'source-empty'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $false -ErrorList $errors

        [System.IO.Directory]::Exists($sourceDir) | Should -BeFalse
        $errors.Count | Should -Be 0
    }

    It 'does not throw when Get-ChildItem encounters an access error' {
        # Error-handling behaviour is also covered by the Get-SourceDirectoryItems unit test below.
        $sourceDir = Join-Path $TestDrive 'source-unreadable'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        Mock Get-ChildItem { Write-Error 'Access to the path is denied.' }
        $errors = [System.Collections.Generic.List[string]]::new()

        { Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $false -ErrorList $errors } |
        Should -Not -Throw
    }

    It 'does nothing when ShouldDeleteSource is false' {
        $sourceDir = Join-Path $TestDrive 'source-nodelete'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $sourceDir 'file.txt') -Value 'data'
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $false -ShouldCleanNonZips $false -ErrorList $errors

        Test-Path -LiteralPath $sourceDir | Should -BeTrue
        $errors.Count | Should -Be 0
    }

    It 'leaves directory intact when -WhatIf is active' {
        $sourceDir = Join-Path $TestDrive 'source-whatif'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-SourceDirectory -SourceDir $sourceDir -ShouldDeleteSource $true -ShouldCleanNonZips $false -ErrorList $errors -WhatIf

        Test-Path -LiteralPath $sourceDir | Should -BeTrue
        $errors.Count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# Private helper unit tests — dot-source each file so functions are callable
# without needing InModuleScope
# ---------------------------------------------------------------------------

Describe 'Get-SourceDirectoryItems (private)' {
    BeforeAll {
        . (Join-Path $Script:privPath 'Get-SourceDirectoryItems.ps1')
    }

    It 'returns an empty array for an empty directory' {
        $dir = Join-Path $TestDrive 'gsi-empty'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null

        $result = Get-SourceDirectoryItems -SourceDir $dir

        $result | Should -BeNullOrEmpty
    }

    It 'returns all items recursively' {
        $dir = Join-Path $TestDrive 'gsi-content'
        New-Item -ItemType Directory -Path (Join-Path $dir 'sub') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'sub' | Join-Path -ChildPath 'file.txt') -Value 'x'

        $result = Get-SourceDirectoryItems -SourceDir $dir

        $result.Count | Should -Be 2
    }

    It 'surfaces enumeration errors as warnings and does not throw' {
        $dir = Join-Path $TestDrive 'gsi-nothrow'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Mock Get-ChildItem { Write-Error 'Denied.' }

        { Get-SourceDirectoryItems -SourceDir $dir } | Should -Not -Throw
    }
}

Describe 'Test-HasBlockingZips (private)' {
    BeforeAll {
        . (Join-Path $Script:privPath 'Test-HasBlockingZips.ps1')
    }

    It 'returns $true and records an error when zip files remain' {
        $zip    = [pscustomobject]@{ PSIsContainer = $false; Extension = '.zip'; FullName = 'C:\src\leftover.zip' }
        $errors = [System.Collections.Generic.List[string]]::new()

        $result = Test-HasBlockingZips -Remaining @($zip) -SourceDir 'C:\src' -ErrorList $errors

        $result       | Should -BeTrue
        $errors.Count | Should -Be 1
        $errors[0]    | Should -BeLike '*zip file*remain*'
    }

    It 'returns $false and records nothing when no zip files remain' {
        $txt    = [pscustomobject]@{ PSIsContainer = $false; Extension = '.txt'; FullName = 'C:\src\readme.txt' }
        $errors = [System.Collections.Generic.List[string]]::new()

        $result = Test-HasBlockingZips -Remaining @($txt) -SourceDir 'C:\src' -ErrorList $errors

        $result       | Should -BeFalse
        $errors.Count | Should -Be 0
    }

    It 'returns $false and records nothing for an empty remaining list' {
        $errors = [System.Collections.Generic.List[string]]::new()

        $result = Test-HasBlockingZips -Remaining @() -SourceDir 'C:\src' -ErrorList $errors

        $result       | Should -BeFalse
        $errors.Count | Should -Be 0
    }

    It 'counts multiple remaining zips in the error message' {
        $zip1   = [pscustomobject]@{ PSIsContainer = $false; Extension = '.zip'; FullName = 'C:\src\a.zip' }
        $zip2   = [pscustomobject]@{ PSIsContainer = $false; Extension = '.zip'; FullName = 'C:\src\b.zip' }
        $errors = [System.Collections.Generic.List[string]]::new()

        Test-HasBlockingZips -Remaining @($zip1, $zip2) -SourceDir 'C:\src' -ErrorList $errors | Out-Null

        $errors[0] | Should -BeLike '*2 zip file*'
    }
}

Describe 'Get-NonZipDeletionBlockReason (private)' {
    BeforeAll {
        . (Join-Path $Script:privPath 'Get-NonZipDeletionBlockReason.ps1')
    }

    It 'returns $null when NonZips list is empty' {
        $result = Get-NonZipDeletionBlockReason -NonZips @() -ShouldCleanNonZips $false -SourceDir 'C:\src'
        $result | Should -BeNullOrEmpty
    }

    It 'returns $null when ShouldCleanNonZips is true regardless of content' {
        $file   = [pscustomobject]@{ PSIsContainer = $false; FullName = 'C:\src\file.txt' }
        $result = Get-NonZipDeletionBlockReason -NonZips @($file) -ShouldCleanNonZips $true -SourceDir 'C:\src'
        $result | Should -BeNullOrEmpty
    }

    It 'returns "non-zip files remain" message when actual files exist and ShouldCleanNonZips is false' {
        $file   = [pscustomobject]@{ PSIsContainer = $false; FullName = 'C:\src\file.txt' }
        $result = Get-NonZipDeletionBlockReason -NonZips @($file) -ShouldCleanNonZips $false -SourceDir 'C:\src'
        $result | Should -BeLike '*non-zip files remain*'
    }

    It 'returns "only empty subdirectories remain" message when only containers exist and ShouldCleanNonZips is false' {
        $dir    = [pscustomobject]@{ PSIsContainer = $true; FullName = 'C:\src\emptydir' }
        $result = Get-NonZipDeletionBlockReason -NonZips @($dir) -ShouldCleanNonZips $false -SourceDir 'C:\src'
        $result | Should -BeLike '*only empty subdirectories remain*'
    }
}

Describe 'Remove-NonZipItems (private)' {
    BeforeAll {
        . (Join-Path $Script:privPath 'Remove-NonZipItems.ps1')
    }

    It 'removes files and subdirs deepest-first in a nested tree' {
        $root = Join-Path $TestDrive 'nonzip-nested'
        $sub  = Join-Path $root 'sub'
        $leaf = Join-Path $sub 'leaf'
        New-Item -ItemType Directory -Path $leaf -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $leaf 'deep.txt') -Value 'deep'
        Set-Content -LiteralPath (Join-Path $sub  'mid.txt')  -Value 'mid'
        Set-Content -LiteralPath (Join-Path $root 'top.txt')  -Value 'top'

        $nonZips = @(Get-ChildItem -LiteralPath $root -Recurse -Force)
        Remove-NonZipItems -NonZips $nonZips -ResolvedSource $root

        $remaining = @(Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue)
        $remaining.Count | Should -Be 0
    }

    It 'silently skips items that have already been removed' {
        $root    = Join-Path $TestDrive 'nonzip-already-gone'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $phantom = [pscustomobject]@{
            PSIsContainer = $false
            Extension     = '.txt'
            FullName      = (Join-Path $root 'gone.txt')
        }

        { Remove-NonZipItems -NonZips @($phantom) -ResolvedSource $root } | Should -Not -Throw
    }
}

Describe 'Remove-DirectoryRobust (private)' {
    BeforeAll {
        . (Join-Path $Script:privPath 'Remove-DirectoryRobust.ps1')
    }

    It 'deletes a non-empty directory and records no error' {
        $dir    = Join-Path $TestDrive 'robust-nonempty'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'file.txt') -Value 'data'
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-DirectoryRobust -ResolvedSource $dir -SourceDir $dir -ErrorList $errors

        [System.IO.Directory]::Exists($dir) | Should -BeFalse
        $errors.Count | Should -Be 0
    }

    It 'deletes an empty directory and records no error' {
        $dir    = Join-Path $TestDrive 'robust-empty'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-DirectoryRobust -ResolvedSource $dir -SourceDir $dir -ErrorList $errors

        [System.IO.Directory]::Exists($dir) | Should -BeFalse
        $errors.Count | Should -Be 0
    }

    It 'is a no-op and records no error when the directory does not exist' {
        $dir    = Join-Path $TestDrive 'robust-nonexistent'
        $errors = [System.Collections.Generic.List[string]]::new()

        Remove-DirectoryRobust -ResolvedSource $dir -SourceDir $dir -ErrorList $errors

        $errors.Count | Should -Be 0
    }
}
