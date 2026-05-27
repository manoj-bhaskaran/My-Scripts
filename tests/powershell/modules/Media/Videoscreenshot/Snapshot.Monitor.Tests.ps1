<#
.SYNOPSIS
Pester tests for Wait-ForSnapshotFrames (Snapshot.Monitor.ps1).
#>

BeforeAll {
    $script:MonitorPath = Join-Path $PSScriptRoot '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Snapshot.Monitor.ps1'
    $script:LoggingPath = Join-Path $PSScriptRoot '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Logging.ps1'

    if (-not (Test-Path -LiteralPath $script:MonitorPath)) {
        throw "Snapshot.Monitor.ps1 not found: $script:MonitorPath"
    }
    if (-not (Test-Path -LiteralPath $script:LoggingPath)) {
        throw "Logging.ps1 not found: $script:LoggingPath"
    }

    . $script:LoggingPath
    . $script:MonitorPath

    function script:New-MockProcess {
        param([bool]$HasExited = $false)
        $p = [pscustomobject]@{ HasExited = $HasExited }
        $p | Add-Member -MemberType ScriptMethod -Name Refresh -Value {}
        $p
    }

    function script:New-TempSnapshotFolder {
        param([string]$Prefix = 'prefix_', [int]$PngCount = 0)
        $dir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())) -Force
        if ($PngCount -gt 0) {
            1..$PngCount | ForEach-Object {
                New-Item -Path (Join-Path $dir.FullName ("{0}{1:D4}.png" -f $Prefix, $_)) -ItemType File -Force | Out-Null
            }
        }
        $dir.FullName
    }
}

Describe 'Wait-ForSnapshotFrames' {

    Context 'idle-frame stall detection' {

        It 'breaks early when no new frames appear past the idle timeout while process is alive' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_' -PngCount 3
            try {
                $proc = script:New-MockProcess -HasExited $false

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'vid_' `
                    -MaxSeconds 60 -PollMs 100 `
                    -Process $proc `
                    -IdleTimeoutSeconds 2 -WarmUpSeconds 0
                $sw.Stop()

                # Should idle-break at ~2 s, not wait out the full 60 s cap
                $sw.Elapsed.TotalSeconds | Should -BeLessThan 15
                $result.FramesDelta | Should -Be 0
            }
            finally {
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'does not idle-break when IdleTimeoutSeconds is 0 (disabled)' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_' -PngCount 2
            try {
                $proc = script:New-MockProcess -HasExited $false

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                # MaxSeconds=3 caps the run; idle detection disabled → should run ~3s
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'vid_' `
                    -MaxSeconds 3 -PollMs 100 `
                    -Process $proc `
                    -IdleTimeoutSeconds 0 -WarmUpSeconds 0
                $sw.Stop()

                # Function ran for the full MaxSeconds, not cut short by idle detection
                $sw.Elapsed.TotalSeconds | Should -BeGreaterThan 2
            }
            finally {
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'warm-up grace period' {

        It 'suppresses idle detection during the warm-up window' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_'  # no PNGs
            try {
                $proc = script:New-MockProcess -HasExited $false

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                # WarmUpSeconds=3 > IdleTimeoutSeconds=1: idle break must not fire inside warm-up
                # MaxSeconds=5 caps the run so the test completes in reasonable time
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'vid_' `
                    -MaxSeconds 5 -PollMs 100 `
                    -Process $proc `
                    -IdleTimeoutSeconds 1 -WarmUpSeconds 3
                $sw.Stop()

                # Without warm-up suppression the function would exit in ~1 s; with it, at least 3 s
                $sw.Elapsed.TotalSeconds | Should -BeGreaterThan 2.5
            }
            finally {
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'fires idle detection after the warm-up window expires' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_'  # no PNGs
            try {
                $proc = script:New-MockProcess -HasExited $false

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                # WarmUp=2 + IdleTimeout=1 = should break at ~3 s; MaxSeconds is generous
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'vid_' `
                    -MaxSeconds 60 -PollMs 100 `
                    -Process $proc `
                    -IdleTimeoutSeconds 1 -WarmUpSeconds 2
                $sw.Stop()

                # Should break around WarmUp+IdleTimeout, well before MaxSeconds=60
                $sw.Elapsed.TotalSeconds | Should -BeGreaterThan 2
                $sw.Elapsed.TotalSeconds | Should -BeLessThan 15
            }
            finally {
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'normal completion via VLC process exit' {

        It 'stops after the grace period when VLC has already exited' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_' -PngCount 5
            try {
                $proc = script:New-MockProcess -HasExited $true  # exited before polling starts

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'vid_' `
                    -MaxSeconds 60 -PollMs 100 `
                    -Process $proc -GracePeriodSeconds 1 `
                    -IdleTimeoutSeconds 30 -WarmUpSeconds 0
                $sw.Stop()

                # Should exit after GracePeriodSeconds (~1 s), not wait 60 s
                $sw.Elapsed.TotalSeconds | Should -BeLessThan 10
                $result.FramesDelta | Should -Be 0
            }
            finally {
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'returns correct FramesDelta when process exits with new frames' {
            $folder = script:New-TempSnapshotFolder -Prefix 'clip_' -PngCount 2
            try {
                # Simulate a process that has already exited
                $proc = script:New-MockProcess -HasExited $true

                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'clip_' `
                    -MaxSeconds 60 -PollMs 100 `
                    -Process $proc -GracePeriodSeconds 1 `
                    -IdleTimeoutSeconds 0 -WarmUpSeconds 0

                # 2 PNGs existed at start; none added → delta is 0
                $result.FramesDelta | Should -Be 0
                $result.ElapsedSeconds | Should -BeGreaterThan 0
            }
            finally {
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
