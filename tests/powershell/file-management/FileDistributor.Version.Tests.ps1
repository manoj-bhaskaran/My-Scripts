<#
.SYNOPSIS
Version consistency tests for FileDistributor metadata.

.DESCRIPTION
Ensures script metadata references the single authoritative script version and that
FileDistributor release notes stay in sync with the runtime script version.
#>

BeforeAll {
    $script:FileDistributorPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'file-management' 'FileDistributor.ps1'
    $script:FileDistributorChangelogPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'file-management' 'FileDistributor.CHANGELOG.md'

    if (-not (Test-Path -LiteralPath $script:FileDistributorPath)) {
        throw "FileDistributor script not found: $script:FileDistributorPath"
    }

    if (-not (Test-Path -LiteralPath $script:FileDistributorChangelogPath)) {
        throw "FileDistributor changelog not found: $script:FileDistributorChangelogPath"
    }

    $script:ScriptContent = Get-Content -LiteralPath $script:FileDistributorPath -Raw
    $script:ChangelogContent = Get-Content -LiteralPath $script:FileDistributorChangelogPath -Raw

    $versionMatch = [regex]::Match($script:ScriptContent, '(?m)^\$script:Version\s*=\s*"(?<v>\d+\.\d+\.\d+)"\s*$')
    if (-not $versionMatch.Success) {
        throw 'Unable to resolve $script:Version from FileDistributor.ps1'
    }

    $script:ScriptVersion = $versionMatch.Groups['v'].Value
}

Describe 'FileDistributor script version metadata' {
    It '.VERSION references $script:Version instead of a hardcoded literal' {
        $script:ScriptContent | Should -Match '(?ms)^\s*\.VERSION\s*\r?\n\s*See `\$script:Version`?\.'
    }

    It '.NOTES version line references $script:Version instead of a hardcoded literal' {
        $script:ScriptContent | Should -Match '(?m)^Version:\s*see\s+`\$script:Version\b'
    }

    It 'latest FileDistributor changelog heading matches $script:Version' {
        $headingMatch = [regex]::Match($script:ChangelogContent, '(?m)^##\s+(?<v>\d+\.\d+\.\d+)\b')
        $headingMatch.Success | Should -Be $true
        $headingMatch.Groups['v'].Value | Should -Be $script:ScriptVersion
    }
}
