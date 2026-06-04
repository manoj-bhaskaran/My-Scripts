<#
.SYNOPSIS
Pester tests for Videoscreenshot processed/resume log parsing.
#>

BeforeAll {
    $script:ProcessedLogPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Processed.Log.ps1'
    if (-not (Test-Path -LiteralPath $script:ProcessedLogPath)) {
        throw "Required file not found: $script:ProcessedLogPath"
    }

    . $script:ProcessedLogPath

    # Stub Write-Message so Get-ProcessedVideoSet's catch path does not throw
    function Write-Message { param([string]$Level, [string]$Message) }
}

Describe 'Get-ResumeIndex processed-log status handling' {
    BeforeEach {
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("processed-log-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
        $script:LogPath = Join-Path $script:TempRoot 'processed.tsv'
    }

    AfterEach {
        if ($script:TempRoot -and (Test-Path -LiteralPath $script:TempRoot -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'skips only true successes and deliberately unplayable videos by default' {
        $processed = Join-Path $script:TempRoot 'processed.mp4'
        $notPlayable = Join-Path $script:TempRoot 'not-playable.mp4'
        $failed = Join-Path $script:TempRoot 'failed.mp4'
        $noFrames = Join-Path $script:TempRoot 'no-frames.mp4'
        $probeError = Join-Path $script:TempRoot 'probe-error.mp4'
        $timedOut = Join-Path $script:TempRoot 'timed-out.mp4'

        Set-Content -LiteralPath $script:LogPath -Value @(
            "# comments are ignored",
            "$processed`tProcessed`t`t2026-05-31T00:00:00.000Z",
            "$notPlayable`tSkipped`tNotPlayable`t2026-05-31T00:00:00.000Z",
            "$failed`tFailed`tVLC crashed`t2026-05-31T00:00:00.000Z",
            "$noFrames`tProcessed`tNoFrames`t2026-05-31T00:00:00.000Z",
            "$probeError`tSkipped`tVideoProbeError`t2026-05-31T00:00:00.000Z",
            "$timedOut`tTimedOutProcessed`tCapReached`t2026-05-31T00:00:00.000Z"
        )

        $index = Get-ResumeIndex -Path $script:LogPath

        $index.Contains((Resolve-VideoPath -Path $processed)) | Should -BeTrue
        $index.Contains((Resolve-VideoPath -Path $notPlayable)) | Should -BeTrue
        $index.Contains((Resolve-VideoPath -Path $failed)) | Should -BeFalse
        $index.Contains((Resolve-VideoPath -Path $noFrames)) | Should -BeFalse
        $index.Contains((Resolve-VideoPath -Path $probeError)) | Should -BeFalse
        $index.Contains((Resolve-VideoPath -Path $timedOut)) | Should -BeFalse
    }


    It 'retries NotPlayable entries when RetryUnplayable is set while preserving other status behavior' {
        $processed = Join-Path $script:TempRoot 'processed.mp4'
        $notPlayable = Join-Path $script:TempRoot 'not-playable.mp4'
        $failed = Join-Path $script:TempRoot 'failed.mp4'
        $noFrames = Join-Path $script:TempRoot 'no-frames.mp4'
        $probeError = Join-Path $script:TempRoot 'probe-error.mp4'
        $timedOut = Join-Path $script:TempRoot 'timed-out.mp4'

        Set-Content -LiteralPath $script:LogPath -Value @(
            "$processed`tProcessed`t`t2026-05-31T00:00:00.000Z",
            "$notPlayable`tSkipped`tNotPlayable`t2026-05-31T00:00:00.000Z",
            "$failed`tFailed`tVLC crashed`t2026-05-31T00:00:00.000Z",
            "$noFrames`tProcessed`tNoFrames`t2026-05-31T00:00:00.000Z",
            "$probeError`tSkipped`tVideoProbeError`t2026-05-31T00:00:00.000Z",
            "$timedOut`tTimedOutProcessed`tCapReached`t2026-05-31T00:00:00.000Z"
        )

        $index = Get-ResumeIndex -Path $script:LogPath -RetryUnplayable

        $index.Contains((Resolve-VideoPath -Path $processed)) | Should -BeTrue
        $index.Contains((Resolve-VideoPath -Path $notPlayable)) | Should -BeFalse
        $index.Contains((Resolve-VideoPath -Path $failed)) | Should -BeFalse
        $index.Contains((Resolve-VideoPath -Path $noFrames)) | Should -BeFalse
        $index.Contains((Resolve-VideoPath -Path $probeError)) | Should -BeFalse
        $index.Contains((Resolve-VideoPath -Path $timedOut)) | Should -BeFalse
    }

    It 'treats legacy single-column entries as processed for backward compatibility' {
        $legacy = Join-Path $script:TempRoot 'legacy.mp4'
        Set-Content -LiteralPath $script:LogPath -Value $legacy

        $index = Get-ResumeIndex -Path $script:LogPath

        $index.Contains((Resolve-VideoPath -Path $legacy)) | Should -BeTrue
    }
}

Describe 'Get-ProcessedVideoSet' {
    BeforeAll {
        # Stub Write-Message so tests do not need the full module loaded
        function Write-Message { param([string]$Level, [string]$Message) }
    }

    BeforeEach {
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pvs-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
        $script:LogPath = Join-Path $script:TempRoot 'processed.tsv'
    }

    AfterEach {
        if ($script:TempRoot -and (Test-Path -LiteralPath $script:TempRoot -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns an empty HashSet[string] when the log file does not exist' {
        $result = Get-ProcessedVideoSet -ProcessedLogPath (Join-Path $script:TempRoot 'missing.tsv') -ResumeFile ''

        $result | Should -Not -BeNullOrEmpty
        $result.GetType().GetGenericTypeDefinition().FullName | Should -Be 'System.Collections.Generic.HashSet`1'
        $result.Count | Should -Be 0
    }

    It 'returns a HashSet[string] with processed entries from the log' {
        $video = Join-Path $script:TempRoot 'video.mp4'
        Set-Content -LiteralPath $script:LogPath -Value "$video`tProcessed`t`t2026-06-01T00:00:00.000Z"

        $result = Get-ProcessedVideoSet -ProcessedLogPath $script:LogPath -ResumeFile ''

        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 1
        $result.Contains((Resolve-VideoPath -Path $video)) | Should -BeTrue
    }

    It 'seeds the set with ResumeFile when provided' {
        $resume = Join-Path $script:TempRoot 'resume.mp4'

        $result = Get-ProcessedVideoSet -ProcessedLogPath $script:LogPath -ResumeFile $resume

        $result.Contains((Resolve-VideoPath -Path $resume)) | Should -BeTrue
    }

    It 'does not add ResumeFile when it is empty or whitespace' {
        $result = Get-ProcessedVideoSet -ProcessedLogPath $script:LogPath -ResumeFile ''

        $result.Count | Should -Be 0
    }

    It 'returns an empty HashSet (not $null) when Get-ResumeIndex throws' {
        # Temporarily override Get-ResumeIndex to throw
        function Get-ResumeIndex { param([string]$Path, [switch]$RetryUnplayable) throw 'simulated failure' }

        $result = Get-ProcessedVideoSet -ProcessedLogPath $script:LogPath -ResumeFile ''

        $result | Should -Not -BeNullOrEmpty
        $result.GetType().GetGenericTypeDefinition().FullName | Should -Be 'System.Collections.Generic.HashSet`1'
        $result.Count | Should -Be 0
    }

    It 'normalises an array return from Get-ResumeIndex to a HashSet[string]' {
        $v1 = Join-Path $script:TempRoot 'a.mp4'
        $v2 = Join-Path $script:TempRoot 'b.mp4'
        # Override to return a plain array
        function Get-ResumeIndex { param([string]$Path, [switch]$RetryUnplayable)
            return @((Resolve-VideoPath -Path $v1), (Resolve-VideoPath -Path $v2))
        }

        $result = Get-ProcessedVideoSet -ProcessedLogPath $script:LogPath -ResumeFile ''

        $result.GetType().GetGenericTypeDefinition().FullName | Should -Be 'System.Collections.Generic.HashSet`1'
        $result.Contains((Resolve-VideoPath -Path $v1)) | Should -BeTrue
        $result.Contains((Resolve-VideoPath -Path $v2)) | Should -BeTrue
    }

    It 'passes RetryUnplayable through to Get-ResumeIndex' {
        $script:RetryPassed = $false
        function Get-ResumeIndex {
            param([string]$Path, [switch]$RetryUnplayable)
            $script:RetryPassed = $RetryUnplayable.IsPresent
            [System.Collections.Generic.HashSet[string]]::new()
        }

        Get-ProcessedVideoSet -ProcessedLogPath $script:LogPath -ResumeFile '' -RetryUnplayable | Out-Null

        $script:RetryPassed | Should -BeTrue
    }
}

Describe 'Write-ProcessedLog zero-frame-compatible statuses' {
    BeforeEach {
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("processed-log-write-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
        $script:LogPath = Join-Path $script:TempRoot 'processed.tsv'
    }

    AfterEach {
        if ($script:TempRoot -and (Test-Path -LiteralPath $script:TempRoot -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'accepts Failed/NoFrames rows and leaves them retry-eligible' {
        $video = Join-Path $script:TempRoot 'zero-frame.mp4'

        Write-ProcessedLog -Path $script:LogPath -VideoPath $video -Status Failed -Reason NoFrames
        $index = Get-ResumeIndex -Path $script:LogPath

        $index.GetType().GetGenericTypeDefinition().FullName | Should -Be 'System.Collections.Generic.HashSet`1'
        $index.GetType().GenericTypeArguments[0].FullName | Should -Be 'System.String'
        $line = Get-Content -LiteralPath $script:LogPath -Raw
        $line | Should -Match "`tFailed`tNoFrames`t"
        $index.Contains((Resolve-VideoPath -Path $video)) | Should -BeFalse
    }
}
