Set-StrictMode -Version Latest

Describe 'Move-ZipFilesToParent' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\FileManagement\ZipWorkflow\ZipWorkflow.psm1') -Force
    }

    It 'moves zip files from source to parent directory' {
        $parentDir = Join-Path $TestDrive 'parent'
        $sourceDir = Join-Path $parentDir 'source'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        $zipPath = Join-Path $sourceDir 'test.zip'
        Set-Content -LiteralPath $zipPath -Value 'dummy zip content' -NoNewline

        $result = ZipWorkflow\Move-ZipFilesToParent -SourceDir $sourceDir -QuietMode $true

        $result.Count | Should -Be 1
        $result.Bytes | Should -BeGreaterThan 0
        $result.Destination | Should -Be $parentDir

        [System.IO.File]::Exists($zipPath) | Should -BeFalse
        [System.IO.File]::Exists((Join-Path $parentDir 'test.zip')) | Should -BeTrue
    }

    It 'throws clear error for drive root source directory' {
        Mock Get-Item -ModuleName ZipWorkflow {
            [pscustomobject]@{ Parent = $null; FullName = 'C:\' }
        }

        { ZipWorkflow\Move-ZipFilesToParent -SourceDir 'C:\' -QuietMode $true } | Should -Throw '*drive root*'
    }

    It 'Rename policy: keeps existing parent zip and moves source zip under a unique name on collision' {
        $parentDir = Join-Path $TestDrive 'parent-rename'
        $sourceDir = Join-Path $parentDir 'source'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        $srcZip    = Join-Path $sourceDir 'test.zip'
        $parentZip = Join-Path $parentDir 'test.zip'
        Set-Content -LiteralPath $srcZip    -Value 'new-content'      -NoNewline
        Set-Content -LiteralPath $parentZip -Value 'original-content' -NoNewline

        $result = ZipWorkflow\Move-ZipFilesToParent -SourceDir $sourceDir -QuietMode $true -CollisionPolicy Rename

        $result.Count   | Should -Be 1
        $result.Renamed | Should -Be 1

        [System.IO.File]::Exists($srcZip) | Should -BeFalse
        (Get-Content -LiteralPath $parentZip -Raw) | Should -Be 'original-content'

        $parentZips = @(Get-ChildItem -LiteralPath $parentDir -Filter '*.zip' -File)
        $parentZips.Count | Should -Be 2
    }
}

Describe 'Invoke-ZipExtractions — wrapper delegation' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\FileManagement\ZipExtraction\ZipExtraction.psm1') -Force
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    }

    It 'returns a zero-count summary when source has no zip files, confirming module delegation' {
        $sourceDir = Join-Path $TestDrive 'delegation-src'
        $destDir   = Join-Path $TestDrive 'delegation-dest'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $destDir   -Force | Out-Null

        $errorList = [System.Collections.Generic.List[string]]::new()
        $result = ZipExtraction\Invoke-ZipExtractions `
            -SourceDir      $sourceDir `
            -DestinationDir $destDir `
            -Mode           'PerArchiveSubfolder' `
            -Policy         'Rename' `
            -SafeNameMaxLen 0 `
            -QuietMode      $true `
            -ErrorList      $errorList `
            -ThrottleLimit  1

        $result.ZipCount      | Should -Be 0
        $result.ProcessedZips | Should -Be 0
        $errorList.Count      | Should -Be 0
    }
}

Describe 'Test-ScriptPreconditions' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\FileManagement\ZipWorkflow\ZipWorkflow.psm1') -Force
    }

    It 'throws when source and destination are the same path' {
        Mock Get-FullPath -ModuleName ZipWorkflow { param([string]$Path) $Path }
        $sep = [System.IO.Path]::DirectorySeparatorChar
        $dir = "${sep}precond-same"

        { ZipWorkflow\Test-ScriptPreconditions -SourceDir $dir -DestinationDir $dir } |
            Should -Throw '*Source and destination cannot be the same*'
    }

    It 'throws when destination is inside the source directory' {
        Mock Get-FullPath -ModuleName ZipWorkflow { param([string]$Path) $Path }
        $sep  = [System.IO.Path]::DirectorySeparatorChar
        $src  = "${sep}precond-src"
        $dest = "${sep}precond-src${sep}inner"

        { ZipWorkflow\Test-ScriptPreconditions -SourceDir $src -DestinationDir $dest } |
            Should -Throw '*Destination cannot be inside the source*'
    }

    It 'throws when source is inside the destination directory' {
        Mock Get-FullPath -ModuleName ZipWorkflow { param([string]$Path) $Path }
        $sep  = [System.IO.Path]::DirectorySeparatorChar
        $dest = "${sep}precond-dest"
        $src  = "${sep}precond-dest${sep}inner"

        { ZipWorkflow\Test-ScriptPreconditions -SourceDir $src -DestinationDir $dest } |
            Should -Throw '*Source cannot be inside the destination*'
    }
}

Describe 'Resolve-MoveTarget' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\..\src\powershell\modules\FileManagement\ZipWorkflow\ZipWorkflow.psm1') -Force
    }

    It 'returns PolicyTag None and canonical TargetPath when no collision' {
        $parentDir = Join-Path $TestDrive 'rmt-no-coll'
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        $zipPath = Join-Path $TestDrive 'rmt-no-coll-src.zip'
        Set-Content -LiteralPath $zipPath -Value 'x' -NoNewline
        $zip = Get-Item -LiteralPath $zipPath

        $result = ZipWorkflow\Resolve-MoveTarget -Zip $zip -Parent $parentDir -CollisionPolicy 'Rename'

        $result.PolicyTag  | Should -Be 'None'
        $result.TargetPath | Should -Be (Join-Path $parentDir 'rmt-no-coll-src.zip')
    }

    It 'returns PolicyTag Skip and unchanged TargetPath when collision and policy is Skip' {
        $parentDir = Join-Path $TestDrive 'rmt-skip'
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $parentDir 'dup.zip') -Value 'existing' -NoNewline
        $zipPath = Join-Path $TestDrive 'rmt-skip-src.zip'
        Set-Content -LiteralPath $zipPath -Value 'new' -NoNewline
        Rename-Item -LiteralPath $zipPath -NewName 'dup.zip'
        $zip = Get-Item -LiteralPath (Join-Path $TestDrive 'dup.zip')

        $result = ZipWorkflow\Resolve-MoveTarget -Zip $zip -Parent $parentDir -CollisionPolicy 'Skip'

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

        $result = ZipWorkflow\Resolve-MoveTarget -Zip $zip -Parent $parentDir -CollisionPolicy 'Overwrite'

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

        $result = ZipWorkflow\Resolve-MoveTarget -Zip $zip -Parent $parentDir -CollisionPolicy 'Rename'

        $result.PolicyTag  | Should -Be 'Rename'
        $result.TargetPath | Should -Not -Be (Join-Path $parentDir 'rn.zip')
        $result.TargetPath | Should -BeLike (Join-Path $parentDir 'rn*')
    }
}

Describe 'Expand-ZipsAndClean script structure' {
    It 'contains no script-local helper function definitions' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\src\powershell\file-management\Expand-ZipsAndClean.ps1'
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptText, [ref]$tokens, [ref]$parseErrors)

        $parseErrors | Should -BeNullOrEmpty
        @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)).Count |
            Should -Be 0
    }
}
