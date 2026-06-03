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

    function Write-Message {
        param([string]$Level, [string]$Message)
        # Wrap in try-catch: $script: variable assignment can fail inside Should -Throw
        # ScriptBlock contexts; swallow silently so the caller's throw propagates cleanly.
        try { $script:WriteMessages += [pscustomobject]@{ Level = $Level; Message = $Message } } catch { }
    }
    function Test-CommandAvailable { param([string]$CommandName) $false }

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


Describe 'Test-VideoConfig' {
    It 'accepts legacy configs that provide StopVlcWaitMs without SnapshotTerminationExtraSeconds' {
        $context = Script:New-TestContext
        $context.Config.Remove('SnapshotTerminationExtraSeconds')

        { Test-VideoConfig -Context $context } | Should -Not -Throw
    }

    It 'requires at least one VLC stop flush timing knob' {
        $context = Script:New-TestContext
        $context.Config.Remove('SnapshotTerminationExtraSeconds')
        $context.Config.Remove('StopVlcWaitMs')

        { Test-VideoConfig -Context $context } | Should -Throw -ExpectedMessage '*either SnapshotTerminationExtraSeconds or StopVlcWaitMs*'
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

    It 'waits SnapshotTerminationExtraSeconds before force-killing a still-running dummy VLC process' {
        $context = Script:New-TestContext
        $context.Config.StopVlcWaitMs = 5000
        $context.Config.SnapshotTerminationExtraSeconds = 1
        $process = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30') -PassThru

        Mock Stop-Process { }
        Mock Wait-Process { }

        try {
            $elapsed = Measure-Command { Stop-Vlc -Context $context -Process $process }

            $elapsed.TotalMilliseconds | Should -BeLessThan 3000
            Should -Not -Invoke Stop-Process -ParameterFilter { -not $Force }
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

Describe 'Resolve-VlcExecutable' {
    BeforeAll {
        $script:TempVlcDir = Join-Path ([System.IO.Path]::GetTempPath()) ("resolve-vlc-test-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempVlcDir -Force | Out-Null
        $script:FakeVlcExe = Join-Path $script:TempVlcDir 'vlc.exe'
        [System.IO.File]::WriteAllText($script:FakeVlcExe, '')
    }

    AfterAll {
        Remove-Item -LiteralPath $script:TempVlcDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'returns the path when given an explicit file path that exists' {
        $result = Resolve-VlcExecutable -VlcExe $script:FakeVlcExe
        $result | Should -Be $script:FakeVlcExe
    }

    It 'resolves vlc.exe inside a directory when given an explicit directory path' {
        $result = Resolve-VlcExecutable -VlcExe $script:TempVlcDir
        $result | Should -Be $script:FakeVlcExe
    }

    It 'throws "VLC missing." when an explicit directory contains no vlc.exe' {
        $emptyDir = Join-Path ([System.IO.Path]::GetTempPath()) ("resolve-vlc-empty-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        try {
            { Resolve-VlcExecutable -VlcExe $emptyDir } | Should -Throw -ExpectedMessage '*VLC missing*'
        }
        finally {
            Remove-Item -LiteralPath $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws "VLC missing." when an explicit file path does not exist' {
        $nonExistent = Join-Path ([System.IO.Path]::GetTempPath()) ("no-vlc-{0}.exe" -f [System.Guid]::NewGuid().ToString('N'))
        { Resolve-VlcExecutable -VlcExe $nonExistent } | Should -Throw -ExpectedMessage '*VLC missing*'
    }

    It 'falls back to PATH when no VlcExe is supplied and vlc is available' {
        Mock Test-CommandAvailable { $true }
        Mock Get-Command { [pscustomobject]@{ Source = '/usr/bin/vlc' } } -ParameterFilter { $Name -eq 'vlc' }

        $result = Resolve-VlcExecutable -VlcExe ''
        $result | Should -Be '/usr/bin/vlc'
    }

    It 'throws "VLC missing." when no VlcExe supplied, not on PATH, and default install absent' {
        # Test-CommandAvailable stub returns $false by default; default install path won't exist on CI.
        $script:WriteMessages = @()
        { Resolve-VlcExecutable -VlcExe '' } | Should -Throw -ExpectedMessage '*VLC missing*'
    }
}

Describe 'Initialize-VlcSidecarLog' {
    It 'creates the log file, attaches VlcLogPath to Context, and returns the path' {
        $saveFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("vlc-sidecar-init-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $saveFolder -Force | Out-Null
        $ctx = [pscustomobject]@{}
        $guid = 'testguid1'

        try {
            $result = Initialize-VlcSidecarLog -Context $ctx -SaveFolder $saveFolder -RunGuid $guid
            $expected = Join-Path $saveFolder ".vlc_log_$guid.txt"

            $result | Should -Be $expected
            $ctx.VlcLogPath | Should -Be $expected
            Test-Path -LiteralPath $expected | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $saveFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns $null and attaches $null to Context when the folder is not writable' {
        $ctx = [pscustomobject]@{}
        # Use a path that does not exist as a directory — Initialize-VlcSidecarLog
        # now checks for the container explicitly, so this reliably triggers the failure path.
        $badFolder = Join-Path ([System.IO.Path]::GetTempPath()) ("no-such-{0}" -f [System.Guid]::NewGuid().ToString('N'))

        $result = Initialize-VlcSidecarLog -Context $ctx -SaveFolder $badFolder -RunGuid 'g2'

        $result | Should -BeNullOrEmpty
        $ctx.VlcLogPath | Should -BeNullOrEmpty
    }
}

Describe 'Remove-TempRunFile' {
    It 'no-ops silently when Path is null or empty' {
        { Remove-TempRunFile -Path $null -Label 'test' } | Should -Not -Throw
        { Remove-TempRunFile -Path '' -Label 'test' } | Should -Not -Throw
    }

    It 'no-ops silently when the file does not exist' {
        { Remove-TempRunFile -Path 'C:\NoSuchFile_xyz.tmp' -Label 'test' } | Should -Not -Throw
    }

    It 'removes an existing file' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("remove-temp-{0}.tmp" -f [System.Guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($tmp, '')

        Remove-TempRunFile -Path $tmp -Label 'test file'

        Test-Path -LiteralPath $tmp | Should -BeFalse
    }

    It 'emits a warning when Remove-Item fails' {
        $script:WriteMessages = @()
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("remove-temp-fail-{0}.tmp" -f [System.Guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($tmp, '')

        try {
            Mock Remove-Item { throw 'Access denied' }
            Remove-TempRunFile -Path $tmp -Label 'locked file'
            ($script:WriteMessages | Where-Object { $_.Level -eq 'Warn' }) | Should -HaveCount 1
        }
        finally {
            # Bypass the Remove-Item mock to clean up the real file.
            [System.IO.File]::Delete($tmp)
        }
    }
}
