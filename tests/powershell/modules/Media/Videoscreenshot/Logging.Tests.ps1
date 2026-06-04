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
    $script:FileOperationsModulePath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Core' 'FileOperations' 'FileOperations.psm1'
    $script:ErrorHandlingModulePath  = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Core' 'ErrorHandling' 'ErrorHandling.psm1'

    foreach ($f in $script:LoggingPath, $script:ModuleManifest, $script:AddContentPath, $script:FileOperationsModulePath, $script:ErrorHandlingModulePath) {
        if (-not (Test-Path -LiteralPath $f)) { throw "Required file not found: $f" }
    }

    # Load Core modules so the unit-level tests have Add-ContentWithRetry available
    Import-Module $script:ErrorHandlingModulePath  -Force
    Import-Module $script:FileOperationsModulePath -Force

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

Describe 'Initialize-RunLogFile branching' {
    AfterEach {
        Clear-VideoScreenshotLogFile
        if ($script:TempFolder -and (Test-Path -LiteralPath $script:TempFolder -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns an auto-named path and sets the log sink when LogFile is omitted' {
        $script:TempFolder = (Script:New-TempFolder).FullName

        $result = Initialize-RunLogFile -SaveFolder $script:TempFolder -RunGuid 'abc123' `
            -LogFile '' -LogFileExplicitlyProvided $false -NoLogFile:$false

        $result | Should -Match 'videoscreenshot_\d{8}_\d{6}_abc123\.log$'
        (Get-VideoScreenshotLogFile) | Should -Be $result
    }

    It 'returns an explicit path and sets the log sink when LogFile is supplied' {
        $script:TempFolder = (Script:New-TempFolder).FullName
        $explicitLog = Join-Path $script:TempFolder 'my-run.log'

        $result = Initialize-RunLogFile -SaveFolder $script:TempFolder -RunGuid 'xyz' `
            -LogFile $explicitLog -LogFileExplicitlyProvided $true -NoLogFile:$false

        $result | Should -Be $explicitLog
        (Get-VideoScreenshotLogFile) | Should -Be $explicitLog
    }

    It 'returns $null and clears the log sink when -NoLogFile is set' {
        $script:TempFolder = (Script:New-TempFolder).FullName
        Set-VideoScreenshotLogFile -Path (Join-Path $script:TempFolder 'stale.log')

        $result = Initialize-RunLogFile -SaveFolder $script:TempFolder -RunGuid 'g1' `
            -LogFile '' -LogFileExplicitlyProvided $false -NoLogFile:$true

        $result | Should -BeNullOrEmpty
        (Get-VideoScreenshotLogFile) | Should -BeNullOrEmpty
    }

    It 'returns $null and clears the log sink when an empty LogFile is explicitly provided' {
        $script:TempFolder = (Script:New-TempFolder).FullName
        Set-VideoScreenshotLogFile -Path (Join-Path $script:TempFolder 'stale.log')

        $result = Initialize-RunLogFile -SaveFolder $script:TempFolder -RunGuid 'g2' `
            -LogFile '' -LogFileExplicitlyProvided $true -NoLogFile:$false

        $result | Should -BeNullOrEmpty
        (Get-VideoScreenshotLogFile) | Should -BeNullOrEmpty
    }

    It 'creates a missing parent directory for an explicit log path' {
        $script:TempFolder = (Script:New-TempFolder).FullName
        $newParent = Join-Path $script:TempFolder 'new-subdir'
        $explicitLog = Join-Path $newParent 'run.log'

        $result = Initialize-RunLogFile -SaveFolder $script:TempFolder -RunGuid 'g3' `
            -LogFile $explicitLog -LogFileExplicitlyProvided $true -NoLogFile:$false

        $result | Should -Be $explicitLog
        Test-Path -LiteralPath $newParent -PathType Container | Should -BeTrue
    }

    It 'warns but still returns the path when parent directory creation fails' {
        $script:TempFolder = (Script:New-TempFolder).FullName
        $explicitLog = Join-Path $script:TempFolder 'missing-parent' 'run.log'

        # Force New-Item to throw regardless of OS behaviour — filesystem-level
        # blocking is not reliable across platforms (e.g. Linux may silently swallow ENOTDIR).
        Mock New-Item { throw [System.IO.IOException]::new('simulated directory creation failure') }

        $warnings = & {
            Initialize-RunLogFile -SaveFolder $script:TempFolder -RunGuid 'g4' `
                -LogFile $explicitLog -LogFileExplicitlyProvided $true -NoLogFile:$false
        } 3>&1

        ($warnings | Out-String) | Should -Match 'Unable to create run log directory'
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
