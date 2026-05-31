<#
.SYNOPSIS
Pester tests for Invoke-SnapshotDedup (Snapshot.Dedup.ps1).
#>

BeforeAll {
    $script:DedupPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' `
        'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Snapshot.Dedup.ps1'
    if (-not (Test-Path -LiteralPath $script:DedupPath)) {
        throw "Required file not found: $script:DedupPath"
    }
    . $script:DedupPath

    function Script:New-TempFolder {
        $dir = New-Item -ItemType Directory `
            -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())) `
            -Force
        $dir.FullName
    }

    # Creates a PNG file in $Folder named "${Prefix}{Index:D4}.png" containing $Content bytes.
    function Script:New-FakeFrame {
        param([string]$Folder, [string]$Prefix, [int]$Index, [byte[]]$Content)
        $path = Join-Path $Folder ("{0}{1:D4}.png" -f $Prefix, $Index)
        [System.IO.File]::WriteAllBytes($path, $Content)
        $path
    }

    $script:BytesA = [byte[]]@(1, 2, 3, 4, 5)
    $script:BytesB = [byte[]]@(6, 7, 8, 9, 10)
    $script:BytesC = [byte[]]@(11, 12, 13, 14, 15)
}

Describe 'Invoke-SnapshotDedup' {

    Context 'consecutive identical frames are collapsed' {

        It 'removes all but the first of a run of identical frames' {
            $folder = Script:New-TempFolder
            try {
                1..5 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index $_ -Content $script:BytesA }

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'vid_'

                $result.OriginalCount | Should -Be 5
                $result.KeptCount     | Should -Be 1
                $result.RemovedCount  | Should -Be 4

                $remaining = @(Get-ChildItem $folder -Filter 'vid_*.png' | Sort-Object Name)
                $remaining.Count | Should -Be 1
                $remaining[0].Name | Should -Be 'vid_0001.png'
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'collapses runs but keeps genuine scene changes between runs' {
            $folder = Script:New-TempFolder
            try {
                # 3×A, 2×B, 3×C → 3 unique groups → 3 kept
                1..3 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index $_ -Content $script:BytesA }
                4..5 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index $_ -Content $script:BytesB }
                6..8 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index $_ -Content $script:BytesC }

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'vid_'

                $result.OriginalCount | Should -Be 8
                $result.KeptCount     | Should -Be 3
                $result.RemovedCount  | Should -Be 5

                $remaining = @(Get-ChildItem $folder -Filter 'vid_*.png' | Sort-Object Name)
                $remaining.Count | Should -Be 3
                $remaining[0].Name | Should -Be 'vid_0001.png'
                $remaining[1].Name | Should -Be 'vid_0004.png'
                $remaining[2].Name | Should -Be 'vid_0006.png'
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'does not remove non-consecutive identical frames (A B A pattern)' {
            $folder = Script:New-TempFolder
            try {
                Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index 1 -Content $script:BytesA
                Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index 2 -Content $script:BytesB
                Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index 3 -Content $script:BytesA

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'vid_'

                $result.OriginalCount | Should -Be 3
                $result.KeptCount     | Should -Be 3
                $result.RemovedCount  | Should -Be 0
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'distinct frames are all preserved' {

        It 'keeps every frame when all are distinct' {
            $folder = Script:New-TempFolder
            try {
                Script:New-FakeFrame -Folder $folder -Prefix 'clip_' -Index 1 -Content $script:BytesA
                Script:New-FakeFrame -Folder $folder -Prefix 'clip_' -Index 2 -Content $script:BytesB
                Script:New-FakeFrame -Folder $folder -Prefix 'clip_' -Index 3 -Content $script:BytesC

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'clip_'

                $result.OriginalCount | Should -Be 3
                $result.KeptCount     | Should -Be 3
                $result.RemovedCount  | Should -Be 0
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'handles a single frame without error' {
            $folder = Script:New-TempFolder
            try {
                Script:New-FakeFrame -Folder $folder -Prefix 'solo_' -Index 1 -Content $script:BytesA

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'solo_'

                $result.OriginalCount | Should -Be 1
                $result.KeptCount     | Should -Be 1
                $result.RemovedCount  | Should -Be 0
                (Get-ChildItem $folder -Filter 'solo_*.png').Count | Should -Be 1
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'handles an empty folder without error' {
            $folder = Script:New-TempFolder
            try {
                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'empty_'

                $result.OriginalCount | Should -Be 0
                $result.KeptCount     | Should -Be 0
                $result.RemovedCount  | Should -Be 0
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'prefix isolation' {

        It 'does not touch frames belonging to a different prefix' {
            $folder = Script:New-TempFolder
            try {
                # Target prefix: 2 identical frames → 1 kept
                Script:New-FakeFrame -Folder $folder -Prefix 'video1_' -Index 1 -Content $script:BytesA
                Script:New-FakeFrame -Folder $folder -Prefix 'video1_' -Index 2 -Content $script:BytesA
                # Other prefix: 3 identical frames — must not be touched
                Script:New-FakeFrame -Folder $folder -Prefix 'video2_' -Index 1 -Content $script:BytesB
                Script:New-FakeFrame -Folder $folder -Prefix 'video2_' -Index 2 -Content $script:BytesB
                Script:New-FakeFrame -Folder $folder -Prefix 'video2_' -Index 3 -Content $script:BytesB

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'video1_'

                $result.OriginalCount | Should -Be 2
                $result.RemovedCount  | Should -Be 1

                # Other prefix untouched
                (Get-ChildItem $folder -Filter 'video2_*.png').Count | Should -Be 3
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'IO-error tolerance' {

        It 'skips a frame that cannot be read and continues de-duplication' {
            $folder = Script:New-TempFolder
            try {
                Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index 1 -Content $script:BytesA
                # Frame 2: write zero bytes to simulate a corrupt/empty file that differs from frame 1
                $path2 = Join-Path $folder 'vid_0002.png'
                [System.IO.File]::WriteAllBytes($path2, [byte[]]@())
                Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index 3 -Content $script:BytesA

                # Should not throw even though frame 2 is unusual
                { Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'vid_' } | Should -Not -Throw

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'vid_'
                $result | Should -Not -BeNullOrEmpty
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'return object accuracy' {

        It 'KeptCount + RemovedCount equals OriginalCount' {
            $folder = Script:New-TempFolder
            try {
                1..4 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'v_' -Index $_ -Content $script:BytesA }
                5..6 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'v_' -Index $_ -Content $script:BytesB }

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'v_'

                ($result.KeptCount + $result.RemovedCount) | Should -Be $result.OriginalCount
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'KeptCount matches the actual files remaining on disk' {
            $folder = Script:New-TempFolder
            try {
                1..5 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'v_' -Index $_ -Content $script:BytesA }
                6..7 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'v_' -Index $_ -Content $script:BytesB }

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'v_'

                $onDisk = (Get-ChildItem $folder -Filter 'v_*.png').Count
                $result.KeptCount | Should -Be $onDisk
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'MD5 algorithm override' {

        It 'accepts MD5 as HashAlgorithm and produces correct de-dup results' {
            $folder = Script:New-TempFolder
            try {
                1..3 | ForEach-Object { Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index $_ -Content $script:BytesA }
                Script:New-FakeFrame -Folder $folder -Prefix 'vid_' -Index 4 -Content $script:BytesB

                $result = Invoke-SnapshotDedup -SaveFolder $folder -ScenePrefix 'vid_' -HashAlgorithm 'MD5'

                $result.OriginalCount | Should -Be 4
                $result.KeptCount     | Should -Be 2
                $result.RemovedCount  | Should -Be 2
            }
            finally { Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
