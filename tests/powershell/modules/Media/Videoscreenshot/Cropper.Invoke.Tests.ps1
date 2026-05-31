<#
.SYNOPSIS
Pester tests for Invoke-Cropper package/module invocation behavior.
#>

BeforeAll {
    $script:InvokePath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Cropper.Invoke.ps1'
    if (-not (Test-Path -LiteralPath $script:InvokePath)) {
        throw "Required file not found: $script:InvokePath"
    }

    . $script:InvokePath
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
            @"
#!/usr/bin/env bash
set -euo pipefail
python3 - "`$@" <<'PY'
import json
import os
import sys
from pathlib import Path

log_path = Path(os.environ['FAKE_PYTHON_LOG'])
record = {
    'args': sys.argv[1:],
    'pythonpath': os.environ.get('PYTHONPATH', ''),
}
with log_path.open('a', encoding='utf-8') as handle:
    handle.write(json.dumps(record) + '\n')
sys.exit(0)
PY
"@ | Set-Content -LiteralPath $script:FakePython -NoNewline
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
        $actual.pythonpath | Should -Match ([regex]::Escape((Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'python')).Path))
    }

    It 'keeps omitted PythonScriptPath on module invocation with repository PYTHONPATH' {
        $result = Invoke-Cropper -InputFolder $script:InputFolder -PythonExe $script:FakePython -NoAutoInstall

        $result.ExitCode | Should -Be 0
        $records = Get-Content -LiteralPath $script:InvocationLog | ForEach-Object { $_ | ConvertFrom-Json }
        $actual = $records | Where-Object { $_.args -contains '-m' -and $_.args -contains 'media.crop_colours' } | Select-Object -Last 1

        $actual | Should -Not -BeNullOrEmpty
        $actual.args[0] | Should -Be '-m'
        $actual.args[1] | Should -Be 'media.crop_colours'
        $actual.pythonpath | Should -Match ([regex]::Escape((Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'python')).Path))
    }
}
