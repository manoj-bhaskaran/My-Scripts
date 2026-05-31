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

    It 'skips only true successes and deliberately unplayable videos' {
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

    It 'treats legacy single-column entries as processed for backward compatibility' {
        $legacy = Join-Path $script:TempRoot 'legacy.mp4'
        Set-Content -LiteralPath $script:LogPath -Value $legacy

        $index = Get-ResumeIndex -Path $script:LogPath

        $index.Contains((Resolve-VideoPath -Path $legacy)) | Should -BeTrue
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
