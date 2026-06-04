<#
.SYNOPSIS
Pester tests for Cropper.Invoke.ps1 helpers: Assert-PythonCropperReady, Invoke-CropOnlyMode, and Invoke-Cropper.
#>

BeforeAll {
    $script:InvokePath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Cropper.Invoke.ps1'
    if (-not (Test-Path -LiteralPath $script:InvokePath)) {
        throw "Required file not found: $script:InvokePath"
    }

    . $script:InvokePath

    # Minimal stub so Invoke-CropOnlyMode tests can call Write-Message without the full module loaded.
    if (-not (Get-Command Write-Message -ErrorAction SilentlyContinue)) {
        function script:Write-Message { param([string]$Level, [string]$Message) }
    }

    # Stub Test-CommandAvailable used by Assert-PythonCropperReady.
    if (-not (Get-Command Test-CommandAvailable -ErrorAction SilentlyContinue)) {
        function script:Test-CommandAvailable { param([string]$CommandName) return $true }
    }
}

Describe 'Assert-PythonCropperReady' {
    BeforeEach {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("assert-ready-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterEach {
        if ($script:TempDir -and (Test-Path -LiteralPath $script:TempDir -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws when PythonScriptPath is provided but not found' {
        { Assert-PythonCropperReady -PythonScriptPath 'C:\nonexistent\crop_colours.py' } |
            Should -Throw -ExceptionMessage 'PythonScriptPath not found*'
    }

    It 'throws when PythonExe is provided but not on PATH' {
        $existingScript = Join-Path $script:TempDir 'crop_colours.py'
        New-Item -ItemType File -Path $existingScript | Out-Null

        Mock Test-CommandAvailable { return $false } -ModuleName * -Verifiable

        { Assert-PythonCropperReady -PythonScriptPath $existingScript -PythonExe 'no-such-python' } |
            Should -Throw -ExceptionMessage 'Python executable not found or not on PATH*'
    }

    It 'does not throw when both PythonScriptPath and PythonExe are absent' {
        { Assert-PythonCropperReady } | Should -Not -Throw
    }

    It 'does not throw when PythonScriptPath exists and PythonExe is absent' {
        $existingScript = Join-Path $script:TempDir 'crop_colours.py'
        New-Item -ItemType File -Path $existingScript | Out-Null
        { Assert-PythonCropperReady -PythonScriptPath $existingScript } | Should -Not -Throw
    }
}

Describe 'Invoke-CropOnlyMode' {
    BeforeEach {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("crop-only-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        $script:Messages = [System.Collections.Generic.List[string]]::new()

        # Override Write-Message to capture messages.
        function script:Write-Message { param([string]$Level, [string]$Message) $script:Messages.Add("[$Level] $Message") }
    }

    AfterEach {
        if ($script:TempDir -and (Test-Path -LiteralPath $script:TempDir -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'happy path: calls Invoke-Cropper and emits finish message' {
        $invoked = $false
        function script:Invoke-Cropper {
            $script:invoked = $true
            [pscustomobject]@{ ExitCode = 0; StdErr = '' }
        }
        function script:Assert-PythonCropperReady { }

        Invoke-CropOnlyMode -SaveFolder $script:TempDir -ModuleVersion '3.6.3' -IsDebug $false

        $invoked | Should -Be $true
        ($script:Messages | Where-Object { $_ -match 'finished.*crop-only' }) | Should -Not -BeNullOrEmpty
    }

    It 'emits ignored-parameter warning when IgnoredParams is non-empty' {
        function script:Invoke-Cropper { [pscustomobject]@{ ExitCode = 0; StdErr = '' } }
        function script:Assert-PythonCropperReady { }

        Invoke-CropOnlyMode -SaveFolder $script:TempDir -ModuleVersion '3.6.3' -IsDebug $false -IgnoredParams @('SourceFolder', 'VideoLimit')

        ($script:Messages | Where-Object { $_ -match 'ignoring capture-related' -and $_ -match 'SourceFolder' }) | Should -Not -BeNullOrEmpty
    }

    It 'does not emit ignored-parameter warning when IgnoredParams is empty' {
        function script:Invoke-Cropper { [pscustomobject]@{ ExitCode = 0; StdErr = '' } }
        function script:Assert-PythonCropperReady { }

        Invoke-CropOnlyMode -SaveFolder $script:TempDir -ModuleVersion '3.6.3' -IsDebug $false -IgnoredParams @()

        ($script:Messages | Where-Object { $_ -match 'ignoring capture-related' }) | Should -BeNullOrEmpty
    }

    It 'propagates cropper failure and re-throws' {
        function script:Invoke-Cropper { throw 'Cropper failed (exit 1).' }
        function script:Assert-PythonCropperReady { }

        { Invoke-CropOnlyMode -SaveFolder $script:TempDir -ModuleVersion '3.6.3' -IsDebug $false } |
            Should -Throw
        ($script:Messages | Where-Object { $_ -match '\[Warn\].*Cropper failed' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-Cropper package invocation' {
    BeforeEach {
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("cropper-invoke-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        $script:InputFolder = Join-Path $script:TempRoot 'images'
        New-Item -ItemType Directory -Path $script:InputFolder -Force | Out-Null
        $script:InvocationLog = Join-Path $script:TempRoot 'python-invocations.jsonl'
        $env:FAKE_PYTHON_LOG = $script:InvocationLog

        if ($IsWindows) {
            $script:FakePython = Join-Path $script:TempRoot 'fake-python.cmd'
            $fakePowerShell = Join-Path $script:TempRoot 'fake-python.ps1'
            @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$PythonArgs)
$record = [pscustomobject]@{
    args = $PythonArgs
    pythonpath = [Environment]::GetEnvironmentVariable('PYTHONPATH')
    cwd = (Get-Location).Path
}
$record | ConvertTo-Json -Compress | Add-Content -LiteralPath $env:FAKE_PYTHON_LOG
exit 0
'@ | Set-Content -LiteralPath $fakePowerShell -NoNewline
            @"
@echo off
pwsh -NoLogo -NoProfile -File "$fakePowerShell" %*
"@ | Set-Content -LiteralPath $script:FakePython -NoNewline
        }
        else {
            $script:FakePython = Join-Path $script:TempRoot 'fake-python'
            $fakePythonContent = @'
#!/usr/bin/env pwsh
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$PythonArgs)
$record = [pscustomobject]@{
    args = $PythonArgs
    pythonpath = [Environment]::GetEnvironmentVariable('PYTHONPATH')
    cwd = (Get-Location).Path
}
$record | ConvertTo-Json -Compress | Add-Content -LiteralPath $env:FAKE_PYTHON_LOG
exit 0
'@
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($script:FakePython, $fakePythonContent.Replace("`r`n", "`n"), $utf8NoBom)
            chmod +x $script:FakePython
        }
    }

    AfterEach {
        Remove-Item Env:FAKE_PYTHON_LOG -ErrorAction SilentlyContinue
        if ($script:TempRoot -and (Test-Path -LiteralPath $script:TempRoot -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'uses -PythonScriptPath as a src/python locator and invokes media.crop_colours as a module' {
        $cropperPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'python' 'media' 'crop_colours.py'

        $result = Invoke-Cropper -PythonScriptPath $cropperPath -InputFolder $script:InputFolder -PythonExe $script:FakePython -NoAutoInstall -ReprocessCropped -KeepExistingCrops

        $result.ExitCode | Should -Be 0
        $records = Get-Content -LiteralPath $script:InvocationLog | ForEach-Object { $_ | ConvertFrom-Json }
        $actual = $records | Where-Object { $_.args -contains '-m' -and $_.args -contains 'media.crop_colours' } | Select-Object -Last 1

        $expectedPythonSrc = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'python')).Path

        $actual | Should -Not -BeNullOrEmpty
        $actual.args[0] | Should -Be '-m'
        $actual.args[1] | Should -Be 'media.crop_colours'
        $actual.args | Should -Contain '--input'
        $actual.args | Should -Contain $script:InputFolder
        $actual.args | Should -Contain '--skip-bad-images'
        $actual.args | Should -Contain '--allow-empty'
        $actual.args | Should -Contain '--recurse'
        $actual.args | Should -Contain '--preserve-alpha'
        $actual.args | Should -Contain '--reprocess-cropped'
        $actual.args | Should -Contain '--keep-existing-crops'
        $actual.pythonpath | Should -Match ([regex]::Escape($expectedPythonSrc))
        $actual.cwd | Should -Be $expectedPythonSrc
    }

    It 'keeps omitted PythonScriptPath on module invocation with repository PYTHONPATH' {
        $result = Invoke-Cropper -InputFolder $script:InputFolder -PythonExe $script:FakePython -NoAutoInstall

        $result.ExitCode | Should -Be 0
        $records = Get-Content -LiteralPath $script:InvocationLog | ForEach-Object { $_ | ConvertFrom-Json }
        $actual = $records | Where-Object { $_.args -contains '-m' -and $_.args -contains 'media.crop_colours' } | Select-Object -Last 1

        $expectedPythonSrc = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'python')).Path

        $actual | Should -Not -BeNullOrEmpty
        $actual.args[0] | Should -Be '-m'
        $actual.args[1] | Should -Be 'media.crop_colours'
        $actual.pythonpath | Should -Match ([regex]::Escape($expectedPythonSrc))
        $actual.cwd | Should -Be $expectedPythonSrc
    }
}
