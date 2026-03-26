BeforeAll {
    $script:ConvertToBytesPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'modules' 'Core' 'Logging' 'PurgeLogs' 'Public' 'ConvertTo-Bytes.ps1'
    . $script:ConvertToBytesPath
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
