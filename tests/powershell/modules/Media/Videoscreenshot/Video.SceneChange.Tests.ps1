<#
.SYNOPSIS
Pester tests for scene-change frame selection.
#>

BeforeAll {
    $script:SceneChangePath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Video.SceneChange.ps1'
    $script:StartPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Public' 'Start-VideoBatch.ps1'
    foreach ($path in @($script:SceneChangePath, $script:StartPath)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Required file not found: $path" }
        . $path
    }

    function Assert-Pwsh7OrThrow { }
    function Set-VideoScreenshotLogFile { param([AllowEmptyString()][string]$Path) }
    function Clear-VideoScreenshotLogFile { }
    function Write-Message {
        param([string]$Level, [string]$Message)
        $script:Messages += [pscustomobject]@{ Level = $Level; Message = $Message }
    }
    function New-VideoRunContext {
        param([int]$RequestedFps, [string]$SaveFolder, [string]$RunGuid)
        [pscustomobject]@{
            Version      = 'test'
            Config       = @{
                VideoExtensions                 = @('.mp4')
                VideoProbeTimeoutSeconds        = 1
                SnapshotFallbackTimeoutSeconds  = 1
                SnapshotDurationSlackFactor     = 2.0
                SnapshotMinimumTimeoutSeconds   = 2
                SnapshotDurationGraceSeconds    = 1
                SnapshotIdleTimeoutSeconds      = 0
                SnapshotIdleWarmUpSeconds       = 0
                GdiCaptureDefaultSeconds        = 1
                FrameSelection                  = 'Ratio'
                SceneChange                     = @{
                    Threshold         = 0.35
                    Backend           = 'ffmpeg'
                    IncludeFirstFrame = $true
                    FfmpegArgs        = @('-hide_banner', '-loglevel', 'error', '-nostdin', '-y')
                }
            }
            RunGuid      = $RunGuid
            SaveFolder   = $SaveFolder
            RequestedFps = $RequestedFps
        }
    }
    function Test-FolderWritable { param([string]$Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null; return $true }
    function Test-CommandAvailable { param([string]$CommandName) return $false }
    function Get-ResumeIndex { param([string]$Path, [switch]$RetryUnplayable) $script:LastRetryUnplayable = [bool]$RetryUnplayable; [System.Collections.Generic.HashSet[string]]::new() }
    function Resolve-VideoPath { param([string]$Path) [System.IO.Path]::GetFullPath($Path) }
    function Initialize-RunLogFile { param([string]$SaveFolder, [string]$RunGuid, [AllowEmptyString()][string]$LogFile, [bool]$LogFileExplicitlyProvided, [switch]$NoLogFile) $null }
    function Get-ProcessedVideoSet { param([string]$ProcessedLogPath, [string]$ResumeFile, [switch]$RetryUnplayable) Get-ResumeIndex -Path $ProcessedLogPath -RetryUnplayable:$RetryUnplayable }
    function Measure-CaptureFrameDelta {
        param($SnapStats, $GdiStats, $DedupStats, [int]$PreCount, [string]$ScenePrefix, [string]$SaveFolder, [switch]$UseVlcSnapshots)
        $delta = if ($UseVlcSnapshots -and $null -ne $SnapStats) { [int]$SnapStats.FramesDelta }
                 elseif (-not $UseVlcSnapshots -and $null -ne $GdiStats) { [int]$GdiStats.FramesSaved }
                 else { 0 }
        [pscustomobject]@{ FramesDelta = $delta; AchievedFps = $null }
    }
    function Initialize-PidRegistry { param($Context, [string]$SaveFolder, [string]$RunGuid) Join-Path $SaveFolder 'pids.txt' }
    function Resolve-VlcExecutable { param([string]$VlcExe) $VlcExe }
    function Initialize-VlcSidecarLog { param($Context, [string]$SaveFolder, [string]$RunGuid) $null }
    function Remove-TempRunFile { param([string]$Path, [string]$Label) }
    function Unregister-RunPid { param($Context, [int]$ProcessId) $script:UnregisterRunPidCalls++ }
    function Write-ProcessedLog { param([string]$Path, [string]$VideoPath, [string]$Status, [string]$Reason = '') }
    function Get-VideoDuration { param([string]$Path) return 1 }
    function Wait-ForSnapshotFrames {
        param([string]$SaveFolder, [string]$ScenePrefix, [int]$MaxSeconds, $Process, [int]$IdleTimeoutSeconds, [int]$WarmUpSeconds)
        $script:WaitSnapshotCalls++
        Set-Content -LiteralPath (Join-Path $SaveFolder ("{0}00001.png" -f $ScenePrefix)) -Value 'png' -NoNewline
        [pscustomobject]@{ FramesDelta = 1; ElapsedSeconds = 1; HitMaxSeconds = $false; ProcessAliveAtExit = $false }
    }
    function Start-Vlc {
        $script:StartVlcCalls++
        [pscustomobject]@{ Id = 123 }
    }
    function Stop-Vlc { param($Context, $Process) $script:StopVlcCalls++ }
    function Invoke-GdiCapture { throw 'Invoke-GdiCapture should not be called in these tests.' }
    function Get-FfmpegCommand { return $script:FfmpegCommand }
    function Invoke-FfmpegSceneChangeCapture {
        param(
            [string]$FfmpegExe,
            [string]$VideoPath,
            [string]$SaveFolder,
            [string]$ScenePrefix,
            [double]$Threshold,
            [double]$StopAtSeconds,
            [int]$TimeoutSeconds,
            [bool]$IncludeFirstFrame,
            [string[]]$BaseArgs
        )
        $script:FfmpegCalls += [pscustomobject]@{
            FfmpegExe         = $FfmpegExe
            Threshold         = $Threshold
            TimeoutSeconds    = $TimeoutSeconds
            IncludeFirstFrame = $IncludeFirstFrame
            BaseArgs          = $BaseArgs
        }
        Set-Content -LiteralPath (Join-Path $SaveFolder ("{0}00001.png" -f $ScenePrefix)) -Value 'png' -NoNewline
        [pscustomobject]@{ FramesDelta = 1; ElapsedSeconds = 1; HitMaxSeconds = $false; ProcessAliveAtExit = $false; Backend = 'ffmpeg' }
    }
}

Describe 'Get-FfmpegSceneChangeArgs' {
    It 'builds an ffmpeg select filter with the threshold and output pattern' {
        $ffmpegArgs = Get-FfmpegSceneChangeArgs -VideoPath '/tmp/input.mp4' -OutputPattern '/tmp/out/video_%05d.png' -Threshold 0.42 -StopAtSeconds 12

        $ffmpegArgs | Should -Contain '-vf'
        $ffmpegArgs | Should -Contain "select='eq(n,0)+gt(scene,0.42)'"
        $ffmpegArgs | Should -Contain '-t'
        $ffmpegArgs | Should -Contain '12'
        $ffmpegArgs[-1] | Should -Be '/tmp/out/video_%05d.png'
    }
}


Describe 'Get-SnapshotChangedFrameCount' {
    It 'counts overwritten matching files whose metadata changed even when the file count is unchanged' {
        $before = @{
            '/tmp/slides_00001.png' = [pscustomobject]@{ Length = 10; LastWriteTimeUtcTicks = 100 }
            '/tmp/slides_00002.png' = [pscustomobject]@{ Length = 20; LastWriteTimeUtcTicks = 200 }
        }
        $after = @{
            '/tmp/slides_00001.png' = [pscustomobject]@{ Length = 10; LastWriteTimeUtcTicks = 101 }
            '/tmp/slides_00002.png' = [pscustomobject]@{ Length = 20; LastWriteTimeUtcTicks = 200 }
        }

        Get-SnapshotChangedFrameCount -Before $before -After $after | Should -Be 1
    }

    It 'counts newly-created matching files as changed frames' {
        $before = @{}
        $after = @{
            '/tmp/slides_00001.png' = [pscustomobject]@{ Length = 10; LastWriteTimeUtcTicks = 100 }
            '/tmp/slides_00002.png' = [pscustomobject]@{ Length = 20; LastWriteTimeUtcTicks = 200 }
        }

        Get-SnapshotChangedFrameCount -Before $before -After $after | Should -Be 2
    }
}

Describe 'Start-VideoBatch frame selection' {
    BeforeEach {
        $script:Messages = @()
        $script:FfmpegCalls = @()
        $script:StartVlcCalls = 0
        $script:StopVlcCalls = 0
        $script:UnregisterRunPidCalls = 0
        $script:WaitSnapshotCalls = 0
        $script:FfmpegCommand = $null

        $script:SourceFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("video-scene-source-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        $script:SaveFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("video-scene-save-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:SourceFolder, $script:SaveFolder -Force | Out-Null
        $script:VideoPath = Join-Path $script:SourceFolder 'slides.mp4'
        Set-Content -LiteralPath $script:VideoPath -Value 'fake video' -NoNewline
        $script:FakeVlc = Join-Path $script:SourceFolder 'vlc.exe'
        Set-Content -LiteralPath $script:FakeVlc -Value 'fake vlc' -NoNewline
    }

    AfterEach {
        foreach ($path in @($script:SourceFolder, $script:SaveFolder)) {
            if ($path -and (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'preserves ratio mode by default' {
        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -UseVlcSnapshots -VlcExe $script:FakeVlc

        $script:StartVlcCalls | Should -Be 1
        $script:WaitSnapshotCalls | Should -Be 1
        $script:UnregisterRunPidCalls | Should -Be 1
        $script:FfmpegCalls | Should -HaveCount 0
    }

    It 'routes scene-change mode to ffmpeg when available' {
        $script:FfmpegCommand = '/usr/bin/ffmpeg'

        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -FrameSelection SceneChange -SceneChangeThreshold 0.25

        $script:FfmpegCalls | Should -HaveCount 1
        $script:FfmpegCalls[0].FfmpegExe | Should -Be '/usr/bin/ffmpeg'
        $script:FfmpegCalls[0].Threshold | Should -Be 0.25
        $script:StartVlcCalls | Should -Be 0
        $script:WaitSnapshotCalls | Should -Be 0
    }

    It 'warns and falls back to VLC ratio snapshots when ffmpeg is unavailable' {
        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -FrameSelection SceneChange -VlcExe $script:FakeVlc

        $script:FfmpegCalls | Should -HaveCount 0
        $script:StartVlcCalls | Should -Be 1
        $script:WaitSnapshotCalls | Should -Be 1
        $script:UnregisterRunPidCalls | Should -Be 1
        ($script:Messages | Where-Object { $_.Level -eq 'Warn' -and $_.Message -match 'ffmpeg was not found' }) | Should -HaveCount 1
    }
}
