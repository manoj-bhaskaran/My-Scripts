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

    $pwsh = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
    if (-not $pwsh) { $pwsh = Get-Command -Name 'powershell' -ErrorAction SilentlyContinue }
    if (-not $pwsh) { throw 'No PowerShell executable found; cannot run process tests.' }
    $script:PwshExe = $pwsh.Source

    function Script:New-TestContext {
        param(
            [string]$VlcLogPath = (Join-Path ([System.IO.Path]::GetTempPath()) ("vlc-log-{0}.txt" -f [System.Guid]::NewGuid().ToString('N'))),
            [int]$LogVerbosity = 1
        )

        [pscustomobject]@{
            Config     = @{
                PollIntervalMs            = 10
                StopVlcWaitMs             = 100
                WaitProcessTimeoutSeconds = 1
                Vlc                       = @{
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

        $args = Get-VlcFileLoggingArgs -Context $context

        $args | Should -Be @('--file-logging', '--logfile', $logPath, '--verbose', '2')
    }

    It 'adds --quiet when verbosity is zero' {
        $context = Script:New-TestContext -LogVerbosity 0

        $args = Get-VlcFileLoggingArgs -Context $context

        $args | Should -Contain '--quiet'
        $args | Should -Contain '--verbose'
        $args | Should -Contain '0'
    }
}

Describe 'Start-VlcProcess' {
    It 'does not redirect stdout or stderr and appends VLC file logging arguments' {
        $context = Script:New-TestContext
        $process = Start-VlcProcess -Context $context -Arguments @('-NoProfile', '-Command', 'exit 0') -StartupTimeoutSeconds 1 -VlcExe $script:PwshExe

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
        }
    }

    It 'uses the VLC logfile text in startup failure diagnostics' {
        $context = Script:New-TestContext
        Set-Content -LiteralPath $context.VlcLogPath -Value 'decoder exploded before startup' -NoNewline

        { Start-VlcProcess -Context $context -Arguments @('-NoProfile', '-Command', 'exit 9') -StartupTimeoutSeconds 1 -VlcExe $script:PwshExe } |
            Should -Throw -ExpectedMessage '*decoder exploded before startup*'

        Remove-Item -LiteralPath $context.VlcLogPath -Force -ErrorAction SilentlyContinue
    }
}
