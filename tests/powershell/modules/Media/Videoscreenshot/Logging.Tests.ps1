<#
.SYNOPSIS
Pester tests for Videoscreenshot run-log routing.
#>

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot'
    $script:LoggingPath = Join-Path $script:ModuleRoot 'Private' 'Logging.ps1'
    $script:ModuleManifest = Join-Path $script:ModuleRoot 'Videoscreenshot.psd1'
    # Add-ContentWithRetry moved from Private/IO.Helpers.ps1 to Core/FileOperations
    $script:AddContentPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Core' 'FileOperations' 'Public' 'Add-ContentWithRetry.ps1'

    foreach ($f in $script:LoggingPath, $script:ModuleManifest, $script:AddContentPath) {
        if (-not (Test-Path -LiteralPath $f)) { throw "Required file not found: $f" }
    }

    . $script:AddContentPath
    . $script:LoggingPath

    function Script:New-TempFolder {
        New-Item -ItemType Directory `
            -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))) `
            -Force
    }
}

Describe 'Write-Message run-log routing' {
    AfterEach {
        Clear-VideoScreenshotLogFile
        if ($script:TempFolder -and (Test-Path -LiteralPath $script:TempFolder -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'writes formatted lines to an explicit -LogFile path' {
        $script:TempFolder = (Script:New-TempFolder).FullName
        $log = Join-Path $script:TempFolder 'explicit.log'

        Write-Message -Level Info -Message 'explicit file message' -LogFile $log -Quiet

        $content = Get-Content -LiteralPath $log -Raw
        $content | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO \] explicit file message'
    }

    It 'uses the module-scoped default when -LogFile is omitted' {
        $script:TempFolder = (Script:New-TempFolder).FullName
        $log = Join-Path $script:TempFolder 'default.log'

        Set-VideoScreenshotLogFile -Path $log
        Write-Message -Level Warn -Message 'helper-visible warning' -Quiet

        Get-Content -LiteralPath $log -Raw | Should -Match '\[WARN \] helper-visible warning'
    }

    It 'lets an explicit empty -LogFile opt out of the module-scoped default for one call' {
        $script:TempFolder = (Script:New-TempFolder).FullName
        $log = Join-Path $script:TempFolder 'default.log'

        Set-VideoScreenshotLogFile -Path $log
        Write-Message -Level Info -Message 'console only' -LogFile '' -Quiet

        Test-Path -LiteralPath $log | Should -BeFalse
    }

    It 'surfaces file-write failures as warnings without throwing' {
        $script:TempFolder = (Script:New-TempFolder).FullName

        $warnings = & { Write-Message -Level Info -Message 'cannot append to directory' -LogFile $script:TempFolder -Quiet } 3>&1

        ($warnings | Out-String) | Should -Match 'failed to write to logfile'
    }
}

Describe 'Start-VideoBatch run-log defaults' {
    BeforeEach {
        $script:TempFolder = (Script:New-TempFolder).FullName
        $script:SourceFolder = Join-Path $script:TempFolder 'videos'
        $script:SaveFolder = Join-Path $script:TempFolder 'shots'
        New-Item -ItemType Directory -Path $script:SourceFolder, $script:SaveFolder -Force | Out-Null
        $script:FakeVlc = Join-Path $script:TempFolder 'vlc.exe'
        Set-Content -LiteralPath $script:FakeVlc -Value 'fake vlc' -NoNewline

        Import-Module $script:ModuleManifest -Force
    }

    AfterEach {
        Remove-Module Videoscreenshot -Force -ErrorAction SilentlyContinue
        Clear-VideoScreenshotLogFile
        if ($script:TempFolder -and (Test-Path -LiteralPath $script:TempFolder -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates a default run log under SaveFolder when -LogFile is omitted' {
        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -VlcExe $script:FakeVlc

        $logs = Get-ChildItem -LiteralPath $script:SaveFolder -Filter 'videoscreenshot_*.log' -File
        $logs | Should -HaveCount 1
        (Get-Content -LiteralPath $logs[0].FullName -Raw) | Should -Match 'Run log file:'
    }

    It 'does not create a run log when -NoLogFile is supplied' {
        Start-VideoBatch -SourceFolder $script:SourceFolder -SaveFolder $script:SaveFolder -VlcExe $script:FakeVlc -NoLogFile

        @(Get-ChildItem -LiteralPath $script:SaveFolder -Filter 'videoscreenshot_*.log' -File) | Should -HaveCount 0
    }
}
