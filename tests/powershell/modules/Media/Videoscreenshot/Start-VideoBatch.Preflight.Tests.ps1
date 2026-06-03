<#
.SYNOPSIS
Pester tests for Start-VideoBatch pre-flight video validation.
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
            }
            RunGuid = $RunGuid
            SaveFolder = $SaveFolder
            RequestedFps = $RequestedFps
        }
    }
    function Test-FolderWritable { param([string]$Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null; return $true }
    function Test-CommandAvailable { param([string]$CommandName) $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue) }
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
    function Test-VideoPlayable {
        param([string]$Path, [string]$VlcExe, [int]$TimeoutSeconds)
        $script:ProbeCalls += [pscustomobject]@{ Path = $Path; VlcExe = $VlcExe; TimeoutSeconds = $TimeoutSeconds }
        return $false
    }
    function Start-Vlc {
        $script:StartVlcCalls++
        throw 'Start-Vlc should not be called for an unplayable pre-flight result.'
    }
}

Describe 'Start-VideoBatch -VerifyVideos pre-flight' {
    BeforeEach {
        $script:ProbeCalls = @()
        $script:ProcessedLogCalls = @()
        $script:StartVlcCalls = 0
        $script:LastRetryUnplayable = $null

        $script:SourceFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("video-source-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        $script:SaveFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("video-save-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:SourceFolder, $script:SaveFolder -Force | Out-Null
        $script:VideoPath = Join-Path $script:SourceFolder 'bad.mp4'
        Set-Content -LiteralPath $script:VideoPath -Value 'not a video' -NoNewline
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

    It 'skips and logs unplayable videos without launching the main VLC session' {
        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -VlcExe $script:FakeVlc -VerifyVideos -VideoProbeTimeoutSeconds 3

        $script:StartVlcCalls | Should -Be 0
        $script:ProbeCalls | Should -HaveCount 1
        $script:ProbeCalls[0].TimeoutSeconds | Should -Be 3
        $script:ProcessedLogCalls | Should -HaveCount 1
        $script:ProcessedLogCalls[0].Status | Should -Be 'Skipped'
        $script:ProcessedLogCalls[0].Reason | Should -Be 'NotPlayable'
    }

    It 'passes RetryUnplayable through to the resume index builder' {
        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -VlcExe $script:FakeVlc -RetryUnplayable -IncludeExtensions '.webm'

        $script:LastRetryUnplayable | Should -BeTrue
    }
}
