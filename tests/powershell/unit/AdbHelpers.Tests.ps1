BeforeAll {
    $script:modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'modules' 'Android' 'AdbHelpers' 'AdbHelpers.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'AdbHelpers module exports' {
    It 'exports the expected public commands' {
        $commands = Get-Command -Module AdbHelpers

        $commands.Name | Should -Contain 'Confirm-Device'
        $commands.Name | Should -Contain 'Get-RemoteFileCount'
        $commands.Name | Should -Contain 'Get-RemoteSize'
        $commands.Name | Should -Contain 'Invoke-AdbSh'
        $commands.Name | Should -Contain 'Test-Adb'
        $commands.Name | Should -Contain 'Test-HostTar'
        $commands.Name | Should -Contain 'Test-PhoneTar'
    }
}

Describe 'Test-HostTar' {
    It 'skips tar lookup in pull mode' {
        Mock Get-Command { throw 'tar lookup should not run in pull mode' } -ModuleName AdbHelpers -ParameterFilter { $Name -eq 'tar' }

        { Test-HostTar -Mode Pull } | Should -Not -Throw
        Should -Invoke Get-Command -ModuleName AdbHelpers -Times 0 -Exactly -ParameterFilter { $Name -eq 'tar' }
    }

    It 'throws when tar is unavailable in tar mode' {
        Mock Get-Command { $null } -ModuleName AdbHelpers -ParameterFilter { $Name -eq 'tar' }

        { Test-HostTar -Mode Tar } | Should -Throw '*Windows tar.exe not found*'
    }
}

Describe 'Test-PhoneTar' {
    It 'skips the adb probe in pull mode' {
        Mock Invoke-AdbSh { throw 'adb probe should not run in pull mode' } -ModuleName AdbHelpers

        { Test-PhoneTar -Mode Pull } | Should -Not -Throw
        Should -Invoke Invoke-AdbSh -ModuleName AdbHelpers -Times 0 -Exactly
    }

    It 'passes debug parameters through to Invoke-AdbSh' {
        Mock Invoke-AdbSh { '0' } -ModuleName AdbHelpers -ParameterFilter { $DebugMode -and $DebugLog -eq 'TestDrive:/adb-debug.log' }

        { Test-PhoneTar -Mode Tar -DebugMode -DebugLog 'TestDrive:/adb-debug.log' } | Should -Not -Throw
        Should -Invoke Invoke-AdbSh -ModuleName AdbHelpers -Times 1 -Exactly -ParameterFilter { $DebugMode -and $DebugLog -eq 'TestDrive:/adb-debug.log' }
    }
}

Describe 'Invoke-AdbSh' {
    BeforeEach {
        $script:lastAdbArgs = $null
    }

    It 'preserves control-structure newlines when flattening the shell script' {
        Mock Invoke-AdbCommand {
            param([Parameter(ValueFromRemainingArguments = $true)] $Arguments)
            $script:lastAdbArgs = $Arguments
            'ok'
        } -ModuleName AdbHelpers

        $result = Invoke-AdbSh -Script "if true`nthen`necho hi`nfi"

        $result | Should -Be 'ok'
        $script:lastAdbArgs[0] | Should -Be 'shell'
        $script:lastAdbArgs[1] | Should -Be "if true`nthen`necho hi`nfi"
    }

    It 'writes debug log entries when debug logging is enabled' {
        Mock Invoke-AdbCommand { 'payload' } -ModuleName AdbHelpers
        Mock Add-Content { } -ModuleName AdbHelpers -ParameterFilter { $Path -eq 'TestDrive:/adb-debug.log' }

        Invoke-AdbSh -Script 'echo hi' -DebugMode -DebugLog 'TestDrive:/adb-debug.log' | Out-Null

        Should -Invoke Add-Content -ModuleName AdbHelpers -Times 2 -ParameterFilter { $Path -eq 'TestDrive:/adb-debug.log' }
    }
}

Describe 'Remote metadata helpers' {
    It 'parses the remote byte count from Invoke-AdbSh output' {
        Mock Invoke-AdbSh { "4096`n" } -ModuleName AdbHelpers -ParameterFilter { $DebugMode -and $DebugLog -eq 'TestDrive:/adb-debug.log' }

        $result = Get-RemoteSize -RemoteParent '/sdcard' -RemoteLeaf 'DCIM' -DebugMode -DebugLog 'TestDrive:/adb-debug.log'

        $result | Should -Be 4096
        Should -Invoke Invoke-AdbSh -ModuleName AdbHelpers -Times 1 -Exactly -ParameterFilter { $DebugMode -and $DebugLog -eq 'TestDrive:/adb-debug.log' }
    }

    It 'returns zero for blank remote byte output' {
        Mock Invoke-AdbSh { '' } -ModuleName AdbHelpers

        Get-RemoteSize -RemoteParent '/sdcard' -RemoteLeaf 'DCIM' | Should -Be 0
    }

    It 'parses the remote file count from Invoke-AdbSh output' {
        Mock Invoke-AdbSh { "27`n" } -ModuleName AdbHelpers -ParameterFilter { $DebugMode -and $DebugLog -eq 'TestDrive:/adb-debug.log' }

        $result = Get-RemoteFileCount -RemoteParent '/sdcard' -RemoteLeaf 'DCIM' -DebugMode -DebugLog 'TestDrive:/adb-debug.log'

        $result | Should -Be 27
        Should -Invoke Invoke-AdbSh -ModuleName AdbHelpers -Times 1 -Exactly -ParameterFilter { $DebugMode -and $DebugLog -eq 'TestDrive:/adb-debug.log' }
    }
}
