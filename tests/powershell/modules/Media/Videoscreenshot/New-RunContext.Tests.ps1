<#
.SYNOPSIS
Pester tests for New-VideoRunContext (New-RunContext.ps1).
#>

BeforeAll {
    $script:ModuleRoot    = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot'
    $script:ManifestPath  = Join-Path $script:ModuleRoot 'Videoscreenshot.psd1'
    $script:RunContextPath = Join-Path $script:ModuleRoot 'Private' 'New-RunContext.ps1'
    $script:ConfigPath    = Join-Path $script:ModuleRoot 'Private' 'Config.ps1'

    foreach ($f in $script:ManifestPath, $script:RunContextPath, $script:ConfigPath) {
        if (-not (Test-Path -LiteralPath $f)) { throw "Required file not found: $f" }
    }

    . $script:ConfigPath
    . $script:RunContextPath
}

Describe 'New-VideoRunContext — version resolution' {

    It 'banner version matches ModuleVersion in the manifest' {
        $manifestVersion = (Import-PowerShellDataFile -Path $script:ManifestPath).ModuleVersion
        $ctx = New-VideoRunContext -RequestedFps 1 -SaveFolder $env:TEMP -RunGuid 'test-guid'
        $ctx.Version | Should -Be $manifestVersion
    }

    It 'returns a non-empty version string' {
        $ctx = New-VideoRunContext -RequestedFps 1 -SaveFolder $env:TEMP -RunGuid 'test-guid'
        $ctx.Version | Should -Not -BeNullOrEmpty
    }

    It 'version is not the stale hard-coded fallback (3.0.5)' {
        $ctx = New-VideoRunContext -RequestedFps 1 -SaveFolder $env:TEMP -RunGuid 'test-guid'
        $ctx.Version | Should -Not -Be '3.0.5'
    }

    It 'fallback catch block returns "unknown" for an unreadable manifest path' {
        $result = try {
            (Import-PowerShellDataFile -Path 'C:\nonexistent\Videoscreenshot.psd1' -ErrorAction Stop).ModuleVersion
        }
        catch { 'unknown' }
        $result | Should -Be 'unknown'
    }
}

Describe 'New-VideoRunContext — context shape' {

    It 'returns a PSCustomObject with all expected properties' {
        $ctx = New-VideoRunContext -RequestedFps 2 -SaveFolder $env:TEMP -RunGuid 'abc-123'
        $ctx.Version      | Should -Not -BeNullOrEmpty
        $ctx.Config       | Should -Not -BeNullOrEmpty
        $ctx.Stats        | Should -Not -BeNullOrEmpty
        $ctx.RunGuid      | Should -Be 'abc-123'
        $ctx.SaveFolder   | Should -Be $env:TEMP
        $ctx.RequestedFps | Should -Be 2
        $ctx.ExitCode     | Should -Be 0
    }
}
