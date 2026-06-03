<#
.SYNOPSIS
Pester tests for Start-VideoBatch processed-log status writes.
#>

BeforeAll {
    $script:StartPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Public' 'Start-VideoBatch.ps1'
    if (-not (Test-Path -LiteralPath $script:StartPath)) {
        throw "Required file not found: $script:StartPath"
    }

    . $script:StartPath

    function Assert-Pwsh7OrThrow { }
    function Write-Message { param([string]$Level, [string]$Message) }
    function Set-VideoScreenshotLogFile { param([AllowEmptyString()][string]$Path) $script:TestRunLogFile = $Path }
    function Clear-VideoScreenshotLogFile { $script:TestRunLogFile = $null }
    function New-VideoRunContext {
        param([int]$RequestedFps, [string]$SaveFolder, [string]$RunGuid)
        [pscustomobject]@{
            Version = 'test'
            Config = @{
                VideoExtensions                 = @('.mp4')
                VideoProbeTimeoutSeconds        = 1
                SnapshotFallbackTimeoutSeconds  = 1
                SnapshotDurationSlackFactor     = 2.0
                SnapshotMinimumTimeoutSeconds   = 2
                SnapshotDurationGraceSeconds    = 1
                SnapshotIdleTimeoutSeconds      = 0
                SnapshotIdleWarmUpSeconds       = 0
                GdiCaptureDefaultSeconds        = 1
                VlcLogVerbosity                 = 1
            }
            RunGuid = $RunGuid
            SaveFolder = $SaveFolder
            RequestedFps = $RequestedFps
        }
    }
    function Test-FolderWritable { param([string]$Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null; return $true }
    function Get-ResumeIndex { param([string]$Path, [switch]$RetryUnplayable) $script:LastRetryUnplayable = [bool]$RetryUnplayable; [System.Collections.Generic.HashSet[string]]::new() }
    function Resolve-VideoPath { param([string]$Path) [System.IO.Path]::GetFullPath($Path) }
    function Initialize-PidRegistry { param($Context, [string]$SaveFolder, [string]$RunGuid) Join-Path $SaveFolder 'pids.txt' }
    function Resolve-VlcExecutable { param([string]$VlcExe) $VlcExe }
    function Initialize-VlcSidecarLog { param($Context, [string]$SaveFolder, [string]$RunGuid) $null }
    function Remove-TempRunFile { param([string]$Path, [string]$Label) }
    function Write-ProcessedLog {
        param([string]$Path, [string]$VideoPath, [string]$Status, [string]$Reason = '')
        $script:ProcessedLogCalls += [pscustomobject]@{ Path = $Path; VideoPath = $VideoPath; Status = $Status; Reason = $Reason }
    }
    function Start-Vlc {
        param($Context, [string]$VideoPath, [string]$SaveFolder, [switch]$UseVlcSnapshots, [int]$RequestedFps, [double]$StopAtSeconds, [switch]$GdiFullscreen, [int]$StartupTimeoutSeconds, [string]$VlcExe, [switch]$NoAudio)
        $script:StartVlcCalls++
        return [pscustomobject]@{ Id = 12345 }
    }
    function Wait-ForSnapshotFrames {
        param([string]$SaveFolder, [string]$ScenePrefix, [int]$MaxSeconds, $Process, [int]$IdleTimeoutSeconds, [int]$WarmUpSeconds)
        $script:WaitMaxSeconds = $MaxSeconds
        return [pscustomobject]@{ FramesDelta = $script:WaitFramesDelta; ElapsedSeconds = 1; HitMaxSeconds = $script:WaitHitMaxSeconds; ProcessAliveAtExit = $script:WaitProcessAliveAtExit }
    }
    function Get-VideoDuration { param([string]$Path) $script:DetectedDuration }
    function Stop-Vlc { param($Context, $Process) }
    function Unregister-RunPid { param($Context, [int]$ProcessId) }
    function Invoke-Cropper { throw 'Invoke-Cropper should not be called in this test.' }
}

Describe 'Start-VideoBatch processed-log status writes' {
    BeforeEach {
        $script:ProcessedLogCalls = @()
        $script:StartVlcCalls = 0
        $script:WaitFramesDelta = 0
        $script:WaitHitMaxSeconds = $false
        $script:WaitProcessAliveAtExit = $false
        $script:WaitMaxSeconds = 0
        $script:DetectedDuration = 2
        $script:SourceFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("video-source-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        $script:SaveFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("video-save-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:SourceFolder, $script:SaveFolder -Force | Out-Null
        $script:VideoPath = Join-Path $script:SourceFolder 'zero.mp4'
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

    It 'logs zero-frame captures as Failed/NoFrames instead of Processed/NoFrames' {
        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -VlcExe $script:FakeVlc -UseVlcSnapshots -MaxPerVideoSeconds 1

        $script:StartVlcCalls | Should -Be 1
        $script:ProcessedLogCalls | Should -HaveCount 1
        $script:ProcessedLogCalls[0].Status | Should -Be 'Failed'
        $script:ProcessedLogCalls[0].Reason | Should -Be 'NoFrames'
    }

    It 'uses duration slack and floor as a safety-net cap when no explicit cap is supplied' {
        $script:WaitFramesDelta = 2

        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -VlcExe $script:FakeVlc -UseVlcSnapshots -StartupGraceSeconds 2

        # max(duration 2s * slack 2.0, floor 2s) + grace 1s + startup grace 2s
        $script:WaitMaxSeconds | Should -Be 7
        $script:ProcessedLogCalls[0].Status | Should -Be 'Processed'
    }

    It 'logs cap-hit VLC snapshot runs with frames as TimedOutProcessed/SnapshotCapHit' {
        $script:WaitFramesDelta = 3
        $script:WaitHitMaxSeconds = $true
        $script:WaitProcessAliveAtExit = $true

        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -VlcExe $script:FakeVlc -UseVlcSnapshots -MaxPerVideoSeconds 1

        $script:StartVlcCalls | Should -Be 1
        $script:ProcessedLogCalls | Should -HaveCount 1
        $script:ProcessedLogCalls[0].Status | Should -Be 'TimedOutProcessed'
        $script:ProcessedLogCalls[0].Reason | Should -Be 'SnapshotCapHit'
    }
}
