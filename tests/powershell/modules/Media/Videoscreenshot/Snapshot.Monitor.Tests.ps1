<#
.SYNOPSIS
Pester tests for Wait-ForSnapshotFrames (Snapshot.Monitor.ps1).
#>

BeforeAll {
    $script:MonitorPath = Join-Path $PSScriptRoot '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Snapshot.Monitor.ps1'
    $script:LoggingPath = Join-Path $PSScriptRoot '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Logging.ps1'

    foreach ($f in $script:MonitorPath, $script:LoggingPath) {
        if (-not (Test-Path -LiteralPath $f)) { throw "Required file not found: $f" }
    }

    . $script:LoggingPath
    . $script:MonitorPath

    # Locate pwsh for spawning real System.Diagnostics.Process instances
    $pwsh = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
    if (-not $pwsh) { $pwsh = Get-Command -Name 'powershell' -ErrorAction SilentlyContinue }
    if (-not $pwsh) { throw 'No PowerShell executable found; cannot spawn real processes for tests.' }
    $script:PwshExe = $pwsh.Source

    # Starts a real process that stays alive for the duration of a test.
    # -WindowStyle is intentionally omitted: it is Windows-only and throws on Linux.
    function script:New-LongRunningProcess {
        Start-Process -FilePath $script:PwshExe `
            -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 120' `
            -PassThru
    }

    # Starts a real process that exits immediately and waits for it to finish.
    function script:New-AlreadyExitedProcess {
        $p = Start-Process -FilePath $script:PwshExe `
            -ArgumentList '-NoProfile', '-Command', 'exit 0' `
            -PassThru
        $p.WaitForExit(10000) | Out-Null
        $p
    }

    function script:New-TempSnapshotFolder {
        param([string]$Prefix = 'prefix_', [int]$PngCount = 0)
        $dir = New-Item -ItemType Directory `
            -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())) `
            -Force
        if ($PngCount -gt 0) {
            1..$PngCount | ForEach-Object {
                New-Item -Path (Join-Path $dir.FullName ("{0}{1:D4}.png" -f $Prefix, $_)) `
                    -ItemType File -Force | Out-Null
            }
        }
        $dir.FullName
    }
}

Describe 'Wait-ForSnapshotFrames' {

    Context 'idle-frame stall detection' {

        It 'breaks early when no new frames appear past the idle timeout while process is alive' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_' -PngCount 3
            $proc = script:New-LongRunningProcess
            try {
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
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'does not idle-break when IdleTimeoutSeconds is 0 (detection disabled)' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_' -PngCount 2
            $proc = script:New-LongRunningProcess
            try {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                # MaxSeconds=3 is the only exit; idle detection is off
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'vid_' `
                    -MaxSeconds 3 -PollMs 100 `
                    -Process $proc `
                    -IdleTimeoutSeconds 0 -WarmUpSeconds 0
                $sw.Stop()

                # Function ran for the full MaxSeconds, not cut short by idle
                $sw.Elapsed.TotalSeconds | Should -BeGreaterThan 2
            }
            finally {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'warm-up grace period' {

        It 'suppresses idle detection during the warm-up window' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_'  # no PNGs
            $proc = script:New-LongRunningProcess
            try {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                # Without warm-up, IdleTimeout=1 would fire in ~1 s.
                # WarmUpSeconds=3 pushes idle detection past the MaxSeconds=5 cap.
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'vid_' `
                    -MaxSeconds 5 -PollMs 100 `
                    -Process $proc `
                    -IdleTimeoutSeconds 1 -WarmUpSeconds 3
                $sw.Stop()

                # Must have run for at least the warm-up window, not bailed at 1 s
                $sw.Elapsed.TotalSeconds | Should -BeGreaterThan 2.5
            }
            finally {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'fires idle detection after the warm-up window expires' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_'  # no PNGs
            $proc = script:New-LongRunningProcess
            try {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                # WarmUp=2 + IdleTimeout=1 → idle break at ~3 s; MaxSeconds generous
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'vid_' `
                    -MaxSeconds 60 -PollMs 100 `
                    -Process $proc `
                    -IdleTimeoutSeconds 1 -WarmUpSeconds 2
                $sw.Stop()

                $sw.Elapsed.TotalSeconds | Should -BeGreaterThan 2
                $sw.Elapsed.TotalSeconds | Should -BeLessThan 15
            }
            finally {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'normal completion via VLC process exit' {

        It 'stops after the grace period when VLC has already exited' {
            $folder = script:New-TempSnapshotFolder -Prefix 'vid_' -PngCount 5
            $proc = script:New-AlreadyExitedProcess
            try {
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

        It 'returns correct FramesDelta and positive ElapsedSeconds' {
            $folder = script:New-TempSnapshotFolder -Prefix 'clip_' -PngCount 2
            $proc = script:New-AlreadyExitedProcess
            try {
                $result = Wait-ForSnapshotFrames `
                    -SaveFolder $folder -ScenePrefix 'clip_' `
                    -MaxSeconds 60 -PollMs 100 `
                    -Process $proc -GracePeriodSeconds 1 `
                    -IdleTimeoutSeconds 0 -WarmUpSeconds 0

                # 2 PNGs present at start, none added during run → delta is 0
                $result.FramesDelta | Should -Be 0
                $result.ElapsedSeconds | Should -BeGreaterThan 0
            }
            finally {
                Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
