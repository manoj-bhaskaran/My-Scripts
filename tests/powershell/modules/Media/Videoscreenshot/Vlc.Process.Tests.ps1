<#
.SYNOPSIS
Pester tests for VLC process launch and sidecar file logging.
#>

BeforeAll {
    $script:VlcProcessPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Vlc.Process.ps1'
    if (-not (Test-Path -LiteralPath $script:VlcProcessPath)) {
        throw "Required file not found: $script:VlcProcessPath"
    }

    . $script:VlcProcessPath

    function Script:New-NativeExitCommand {
        param(
            [Parameter(Mandatory)][int]$ExitCode
        )

        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("vlc-process-test-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null

        if ($env:OS -eq 'Windows_NT') {
            $path = Join-Path $dir 'fake-vlc.cmd'
            [System.IO.File]::WriteAllText($path, ("@echo off`r`nexit /b {0}`r`n" -f $ExitCode))
        }
        else {
            $path = Join-Path $dir 'fake-vlc'
            [System.IO.File]::WriteAllText($path, ("#!/bin/sh`nexit {0}`n" -f $ExitCode))
            chmod +x $path
        }

        [pscustomobject]@{
            FilePath    = $path
            # Start-VlcProcess requires a non-empty argument array; the fake
            # native command intentionally ignores this placeholder and any
            # appended VLC logging flags.
            Arguments   = @('--ignored-test-arg')
            CleanupPath = $dir
        }
    }

    function Script:New-TestContext {
        param(
            [string]$VlcLogPath = (Join-Path ([System.IO.Path]::GetTempPath()) ("vlc-log-{0}.txt" -f [System.Guid]::NewGuid().ToString('N'))),
            [int]$LogVerbosity = 1
        )

        [pscustomobject]@{
            Config     = @{
                PollIntervalMs                  = 10
                StopVlcWaitMs                   = 100
                SnapshotTerminationExtraSeconds = 1
                WaitProcessTimeoutSeconds       = 1
                Vlc                             = @{
                    LogVerbosity = $LogVerbosity
                }
            }
            VlcLogPath = $VlcLogPath
        }
    }
}

Describe 'Get-VlcFileLoggingArgs' {
    It 'builds VLC sidecar logfile arguments at the configured verbosity' {
        $logPath = Join-Path ([System.IO.Path]::GetTempPath()) 'vlc-sidecar-test.txt'
        $context = Script:New-TestContext -VlcLogPath $logPath -LogVerbosity 2

        $loggingArgs = Get-VlcFileLoggingArgs -Context $context

        $loggingArgs | Should -Be @('--file-logging', '--logfile', $logPath, '--verbose', '2')
    }

    It 'adds --quiet when verbosity is zero' {
        $context = Script:New-TestContext -LogVerbosity 0

        $loggingArgs = Get-VlcFileLoggingArgs -Context $context

        $loggingArgs | Should -Contain '--quiet'
        $loggingArgs | Should -Contain '--verbose'
        $loggingArgs | Should -Contain '0'
    }
}

Describe 'Start-VlcProcess' {
    It 'does not redirect stdout or stderr and appends VLC file logging arguments' {
        $context = Script:New-TestContext
        $fakeVlc = Script:New-NativeExitCommand -ExitCode 0
        $process = Start-VlcProcess -Context $context -Arguments $fakeVlc.Arguments -StartupTimeoutSeconds 1 -VlcExe $fakeVlc.FilePath

        try {
            $process.StartInfo.RedirectStandardOutput | Should -BeFalse
            $process.StartInfo.RedirectStandardError | Should -BeFalse
            $process.StartInfo.Arguments | Should -Match '--file-logging'
            $process.StartInfo.Arguments | Should -Match '--logfile'
            $process.StartInfo.Arguments | Should -Match ([regex]::Escape($context.VlcLogPath))
            $process.StartInfo.Arguments | Should -Match '--verbose'
        }
        finally {
            if ($process -and -not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
            Remove-Item -LiteralPath $context.VlcLogPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $fakeVlc.CleanupPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'uses the VLC logfile text in startup failure diagnostics' {
        $context = Script:New-TestContext
        $fakeVlc = Script:New-NativeExitCommand -ExitCode 9
        Set-Content -LiteralPath $context.VlcLogPath -Value 'decoder exploded before startup' -NoNewline

        { Start-VlcProcess -Context $context -Arguments $fakeVlc.Arguments -StartupTimeoutSeconds 1 -VlcExe $fakeVlc.FilePath } |
            Should -Throw -ExpectedMessage '*decoder exploded before startup*'

        Remove-Item -LiteralPath $context.VlcLogPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $fakeVlc.CleanupPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Stop-Vlc' {
    It 'returns immediately for an already-exited process without requesting termination' {
        $context = Script:New-TestContext
        $fakeVlc = Script:New-NativeExitCommand -ExitCode 0
        $process = Start-VlcProcess -Context $context -Arguments $fakeVlc.Arguments -StartupTimeoutSeconds 1 -VlcExe $fakeVlc.FilePath
        $process.WaitForExit(1000) | Should -BeTrue

        Mock Stop-Process { throw 'Stop-Process should not be called for an already-exited VLC process.' }

        Stop-Vlc -Context $context -Process $process

        Should -Not -Invoke Stop-Process

        Remove-Item -LiteralPath $context.VlcLogPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $fakeVlc.CleanupPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'uses SnapshotTerminationExtraSeconds instead of the legacy StopVlcWaitMs delay before force-kill' {
        $context = Script:New-TestContext
        $context.Config.StopVlcWaitMs = 5000
        $context.Config.SnapshotTerminationExtraSeconds = 1
        $process = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30') -PassThru

        Mock Stop-Process { }
        Mock Wait-Process { }

        try {
            $elapsed = Measure-Command { Stop-Vlc -Context $context -Process $process }

            $elapsed.TotalMilliseconds | Should -BeLessThan 3000
            Should -Invoke Stop-Process -Times 1 -ParameterFilter { -not $Force }
            Should -Invoke Stop-Process -Times 1 -ParameterFilter { $Force }
            Should -Invoke Wait-Process -Times 1 -ParameterFilter { $Timeout -eq $context.Config.WaitProcessTimeoutSeconds }
        }
        finally {
            if ($process -and -not $process.HasExited) {
                $process.Kill($true)
                $process.WaitForExit(1000) | Out-Null
            }
        }
    }

    It 'does not call CloseMainWindow in the dummy-interface stop path' {
        $source = Get-Content -LiteralPath $script:VlcProcessPath -Raw

        $source | Should -Not -Match '\.CloseMainWindow\('
    }
}
