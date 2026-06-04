<#
.SYNOPSIS
Pester tests for Measure-CaptureFrameDelta.
#>

BeforeAll {
    $script:CaptureMetricsPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Capture.Metrics.ps1'
    if (-not (Test-Path -LiteralPath $script:CaptureMetricsPath)) {
        throw "Required file not found: $script:CaptureMetricsPath"
    }

    . $script:CaptureMetricsPath

    function Script:New-TempFolder {
        New-Item -ItemType Directory `
            -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))) `
            -Force
    }

    function Script:Write-PngFiles {
        param([string]$Folder, [string]$Prefix, [int]$Count, [int]$StartIndex = 1)
        for ($i = $StartIndex; $i -lt $StartIndex + $Count; $i++) {
            [System.IO.File]::WriteAllBytes((Join-Path $Folder ('{0}{1:D5}.png' -f $Prefix, $i)), [byte[]]@(0x89, 0x50, 0x4E, 0x47))
        }
    }
}

Describe 'Measure-CaptureFrameDelta — VLC-snapshot path' {
    BeforeEach {
        $script:TempFolder = (Script:New-TempFolder).FullName
    }
    AfterEach {
        Remove-Item -LiteralPath $script:TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'returns FramesDelta and AchievedFps from SnapStats when present' {
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'vid_' -Count 10
        $snap = [pscustomobject]@{ FramesDelta = 10; ElapsedSeconds = 5.0 }

        $result = Measure-CaptureFrameDelta -SnapStats $snap -GdiStats $null -DedupStats $null `
            -PreCount 0 -ScenePrefix 'vid_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        $result.FramesDelta | Should -Be 10
        $result.AchievedFps | Should -Be 2.0
    }

    It 'returns $null AchievedFps when ElapsedSeconds is zero' {
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'vid_' -Count 5
        $snap = [pscustomobject]@{ FramesDelta = 5; ElapsedSeconds = 0 }

        $result = Measure-CaptureFrameDelta -SnapStats $snap -GdiStats $null -DedupStats $null `
            -PreCount 0 -ScenePrefix 'vid_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        $result.FramesDelta | Should -Be 5
        $result.AchievedFps | Should -BeNullOrEmpty
    }

    It 'falls back to disk count when SnapStats is null' {
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'vid_' -Count 7

        $result = Measure-CaptureFrameDelta -SnapStats $null -GdiStats $null -DedupStats $null `
            -PreCount 0 -ScenePrefix 'vid_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        $result.FramesDelta | Should -Be 7
        $result.AchievedFps | Should -BeNullOrEmpty
    }

    It 'subtracts PreCount from the disk fallback count' {
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'vid_' -Count 10

        $result = Measure-CaptureFrameDelta -SnapStats $null -GdiStats $null -DedupStats $null `
            -PreCount 4 -ScenePrefix 'vid_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        $result.FramesDelta | Should -Be 6
    }
}

Describe 'Measure-CaptureFrameDelta — GDI path' {
    BeforeEach {
        $script:TempFolder = (Script:New-TempFolder).FullName
    }
    AfterEach {
        Remove-Item -LiteralPath $script:TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'returns FramesDelta and AchievedFps from GdiStats when present' {
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'gdi_' -Count 6
        $gdi = [pscustomobject]@{ FramesSaved = 6; AchievedFps = 3.0 }

        $result = Measure-CaptureFrameDelta -SnapStats $null -GdiStats $gdi -DedupStats $null `
            -PreCount 0 -ScenePrefix 'gdi_' -SaveFolder $script:TempFolder

        $result.FramesDelta | Should -Be 6
        $result.AchievedFps | Should -Be 3.0
    }

    It 'falls back to disk count when GdiStats is null' {
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'gdi_' -Count 4

        $result = Measure-CaptureFrameDelta -SnapStats $null -GdiStats $null -DedupStats $null `
            -PreCount 0 -ScenePrefix 'gdi_' -SaveFolder $script:TempFolder

        $result.FramesDelta | Should -Be 4
        $result.AchievedFps | Should -BeNullOrEmpty
    }
}

Describe 'Measure-CaptureFrameDelta — dedup reconciliation' {
    BeforeEach {
        $script:TempFolder = (Script:New-TempFolder).FullName
    }
    AfterEach {
        Remove-Item -LiteralPath $script:TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'uses post-dedup disk count when actualFramesDelta > 0' {
        # 10 frames written, dedup kept 7 (removed 3)
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'vid_' -Count 7
        $snap = [pscustomobject]@{ FramesDelta = 10; ElapsedSeconds = 5.0 }
        $dedup = [pscustomobject]@{ OriginalCount = 10; KeptCount = 7; RemovedCount = 3 }

        $result = Measure-CaptureFrameDelta -SnapStats $snap -GdiStats $null -DedupStats $dedup `
            -PreCount 0 -ScenePrefix 'vid_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        $result.FramesDelta | Should -Be 7
    }

    It 'keeps stats-derived delta on overwrite case (actualFramesDelta <= 0) even with dedup' {
        # VLC overwrote 5 pre-existing files — disk count unchanged from preCount
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'vid_' -Count 5
        $snap = [pscustomobject]@{ FramesDelta = 5; ElapsedSeconds = 3.0 }
        $dedup = [pscustomobject]@{ OriginalCount = 5; KeptCount = 5; RemovedCount = 0 }

        $result = Measure-CaptureFrameDelta -SnapStats $snap -GdiStats $null -DedupStats $dedup `
            -PreCount 5 -ScenePrefix 'vid_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        # actualFramesDelta = 5 - 5 = 0, so stats-derived value (5) is kept
        $result.FramesDelta | Should -Be 5
    }

    It 'promotes disk count when disk is higher than stats and dedup did not run' {
        # Stats report 3, but 5 files actually on disk
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'vid_' -Count 5
        $snap = [pscustomobject]@{ FramesDelta = 3; ElapsedSeconds = 2.0 }

        $result = Measure-CaptureFrameDelta -SnapStats $snap -GdiStats $null -DedupStats $null `
            -PreCount 0 -ScenePrefix 'vid_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        $result.FramesDelta | Should -Be 5
    }

    It 'does not demote stats count when disk count is lower (no dedup)' {
        # Stats report 10 frames but only 7 on disk (some may have been removed externally)
        Script:Write-PngFiles -Folder $script:TempFolder -Prefix 'vid_' -Count 7
        $snap = [pscustomobject]@{ FramesDelta = 10; ElapsedSeconds = 5.0 }

        $result = Measure-CaptureFrameDelta -SnapStats $snap -GdiStats $null -DedupStats $null `
            -PreCount 0 -ScenePrefix 'vid_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        # actualFramesDelta (7) is not greater than framesDelta (10), so stats value wins
        $result.FramesDelta | Should -Be 10
    }
}

Describe 'Measure-CaptureFrameDelta — return type' {
    BeforeEach {
        $script:TempFolder = (Script:New-TempFolder).FullName
    }
    AfterEach {
        Remove-Item -LiteralPath $script:TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'always returns a pscustomobject with FramesDelta and AchievedFps properties' {
        $result = Measure-CaptureFrameDelta -SnapStats $null -GdiStats $null -DedupStats $null `
            -PreCount 0 -ScenePrefix 'x_' -SaveFolder $script:TempFolder -UseVlcSnapshots

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain 'FramesDelta'
        $result.PSObject.Properties.Name | Should -Contain 'AchievedFps'
        $result.FramesDelta | Should -BeOfType [int]
    }
}
