BeforeAll {
    $script:ModuleManifestPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'modules' 'Core' 'Logging' 'PurgeLogs.psd1'
    Import-Module $script:ModuleManifestPath -Force
}

AfterAll {
    Remove-Module PurgeLogs -ErrorAction SilentlyContinue
}

Describe "PurgeLogs ConvertTo-Bytes" {
    It "supports KB and K with equivalent values" {
        (ConvertTo-Bytes -Size '10KB') | Should -Be (ConvertTo-Bytes -Size '10K')
        (ConvertTo-Bytes -Size '10K') | Should -Be 10240
    }

    It "supports MB and M with equivalent values" {
        (ConvertTo-Bytes -Size '10MB') | Should -Be (ConvertTo-Bytes -Size '10M')
        (ConvertTo-Bytes -Size '10M') | Should -Be 10485760
    }

    It "supports GB and G with equivalent values" {
        (ConvertTo-Bytes -Size '2GB') | Should -Be (ConvertTo-Bytes -Size '2G')
        (ConvertTo-Bytes -Size '2G') | Should -Be 2147483648
    }

    It "parses suffixes case-insensitively" {
        (ConvertTo-Bytes -Size '10m') | Should -Be (ConvertTo-Bytes -Size '10MB')
        (ConvertTo-Bytes -Size '1g') | Should -Be (ConvertTo-Bytes -Size '1GB')
        (ConvertTo-Bytes -Size '100k') | Should -Be (ConvertTo-Bytes -Size '100KB')
    }

    It "throws for unsupported suffixes" {
        { ConvertTo-Bytes -Size '10TB' } | Should -Throw
    }
}

Describe "PurgeLogs Clear-LogFile" {
    It "supports BeforeTimestamp filtering" {
        $logFile = Join-Path $TestDrive 'before-timestamp.log'
        @(
            '2026-01-01 00:00:00 [INFO] old entry'
            '2026-03-20 12:00:00 [INFO] new entry'
            'line without timestamp'
        ) | Set-Content -Path $logFile -Encoding UTF8

        Clear-LogFile -LogFilePath $logFile -BeforeTimestamp ([datetime]'2026-03-01 00:00:00')

        $remaining = Get-Content -Path $logFile -Encoding UTF8
        $remaining | Should -Contain '2026-03-20 12:00:00 [INFO] new entry'
        $remaining | Should -Contain 'line without timestamp'
        $remaining | Should -Not -Contain '2026-01-01 00:00:00 [INFO] old entry'
    }

    It "allows retention filtering and TruncateIfLarger in one call" {
        $logFile = Join-Path $TestDrive 'retention-and-truncate.log'
        @(
            '2026-01-01 00:00:00 [INFO] old entry'
            '2026-03-25 12:00:00 [INFO] recent entry'
            ('x' * 4096)
        ) | Set-Content -Path $logFile -Encoding UTF8

        Clear-LogFile -LogFilePath $logFile -RetentionDays 30 -TruncateIfLarger '1K'

        (Get-Item -Path $logFile).Length | Should -BeLessOrEqual 1024
    }
}
