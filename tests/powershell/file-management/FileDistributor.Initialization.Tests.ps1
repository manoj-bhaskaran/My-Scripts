<#
.SYNOPSIS
Initialization-focused regression tests for FileDistributor.ps1.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'powershell' 'file-management' 'FileDistributor.ps1'

    if (-not (Test-Path -LiteralPath $script:ScriptPath)) {
        throw "FileDistributor script not found: $script:ScriptPath"
    }

    $runner = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
    if (-not $runner) {
        $runner = Get-Command -Name 'powershell' -ErrorAction SilentlyContinue
    }
    if (-not $runner) {
        throw 'Neither pwsh nor powershell executable is available for subprocess script invocation.'
    }
    $script:PowerShellRunner = $runner.Name

    $script:SourceFolder = Join-Path $TestDrive 'source'
    $script:TargetFolder = Join-Path $TestDrive 'target'
    New-Item -Path $script:SourceFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $script:TargetFolder -ItemType Directory -Force | Out-Null
}

Describe 'FileDistributor initialization behavior' {
    It 'handles path-init failures with Write-Error and exit code 1' {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw

        $content | Should -Match '(?s)try\s*\{\s*\$_paths\s*=\s*Initialize-FileDistributorPaths.*?\}\s*catch\s*\{'
        $content | Should -Match 'Write-Error\s+-Exception\s+\$pathInitError\s+-Category\s+InvalidOperation\s+-ErrorId\s+''FileDistributor\.PathInitializationFailed'''
        $content | Should -Match '(?m)^\s*exit\s+1\s*$'
    }

    It 'does not directly import FileQueue in the entry script' {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        $content | Should -Not -Match 'Import-Module\s+"\$PSScriptRoot\\\.\.\\modules\\FileManagement\\FileQueue\\FileQueue\.psd1"'
    }

    It 'sets DebugMode before the first startup log call in Main()' {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw

        $debugIndex = $content.IndexOf("`$script:DebugMode = (`$DebugPreference -ne 'SilentlyContinue')")
        $firstLogIndex = $content.IndexOf('Write-LogInfo "FileDistributor starting..."')

        $debugIndex | Should -BeGreaterThan -1
        $firstLogIndex | Should -BeGreaterThan -1
        $debugIndex | Should -BeLessThan $firstLogIndex
    }

    It 'uses logger API instead of mutating framework globals directly' {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        $content | Should -Match 'Set-LoggerLogFilePath\s+-Path\s+\$LogFilePath'
        $content | Should -Not -Match '\$Global:LogConfig\.LogFilePath\s*='
    }
}
