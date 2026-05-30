<#
.SYNOPSIS
    Pester unit tests for Move-ImageFileToBatch.ps1 logging behaviour.

.DESCRIPTION
    Covers:
      - Framework log written to -LogDirectory when supplied
      - Framework log written to the module default when -LogDirectory is omitted
      - Error log file derived from -LogDirectory (not treated as a literal file path)
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' '..' '..' `
        'src' 'powershell' 'media' 'Move-ImageFileToBatch.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '..' '..' '..' `
        'src' 'powershell' 'modules' 'Core' 'Logging' 'PowerShellLoggingFramework.psm1'

    # Prefer pwsh; fall back to powershell
    $runner = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
    if (-not $runner) { $runner = Get-Command -Name 'powershell' -ErrorAction SilentlyContinue }
    if (-not $runner) { throw 'Neither pwsh nor powershell is available.' }
    $script:PS = $runner.Source

    # Helper: run the script in a subprocess so module globals don't bleed across tests
    function Invoke-Script {
        param([hashtable]$Args = @{})
        $argList = $Args.GetEnumerator() | ForEach-Object { "-$($_.Key)"; $_.Value }
        & $script:PS -NonInteractive -NoProfile -File $script:ScriptPath @argList 2>&1
    }
}

Describe "Move-ImageFileToBatch — script existence" {
    It "Script file exists" {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It "Script is a .ps1 file" {
        $script:ScriptPath | Should -Match '\.ps1$'
    }
}

Describe "Move-ImageFileToBatch — parameter contract" {
    It "Declares -LogDirectory (not -LogFilePath)" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath, [ref]$null, [ref]$null)
        $params = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $params | Should -Contain 'LogDirectory'
        $params | Should -Not -Contain 'LogFilePath'
    }

    It "Passes -LogDirectory to Initialize-Logger via splatting" {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        $content | Should -Match "resolvedLogDir.*LogDirectory"
    }

    It "Version is 2.1.4 in .NOTES" {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        $content | Should -Match '2\.1\.4'
    }

    It "Retains the picconvert BatchPrefix default" {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        $content | Should -Match '\[string\]\$BatchPrefix = ''picconvert'''
    }
}

Describe "Move-ImageFileToBatch — framework log routing" {
    BeforeEach {
        $script:TmpRoot = Join-Path ([IO.Path]::GetTempPath()) "MIFTBTest_$([guid]::NewGuid())"
        $script:Src    = Join-Path $script:TmpRoot 'src'
        $script:Dst    = Join-Path $script:TmpRoot 'dst'
        $script:LogDir = Join-Path $script:TmpRoot 'logs'
        New-Item -Path $script:Src -ItemType Directory -Force | Out-Null
        New-Item -Path $script:Dst -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:TmpRoot) { Remove-Item $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "Creates log directory when -LogDirectory is supplied" {
        # Run with an empty source; the script completes the rename/copy phases with zero files
        & $script:PS -NonInteractive -NoProfile -File $script:ScriptPath `
            -SourceDir $script:Src -DestDir $script:Dst -LogDirectory $script:LogDir 2>&1 | Out-Null
        Test-Path $script:LogDir | Should -Be $true
    }

    It "Framework log file appears in -LogDirectory" {
        & $script:PS -NonInteractive -NoProfile -File $script:ScriptPath `
            -SourceDir $script:Src -DestDir $script:Dst -LogDirectory $script:LogDir 2>&1 | Out-Null
        $logFiles = Get-ChildItem -Path $script:LogDir -Filter '*_powershell_*.log' -ErrorAction SilentlyContinue
        $logFiles | Should -Not -BeNullOrEmpty
    }

    It "No framework log written to -LogDirectory when parameter is omitted" {
        # Without -LogDirectory the framework writes elsewhere; our custom log dir stays empty
        New-Item -Path $script:LogDir -ItemType Directory -Force | Out-Null
        & $script:PS -NonInteractive -NoProfile -File $script:ScriptPath `
            -SourceDir $script:Src -DestDir $script:Dst 2>&1 | Out-Null
        $logFiles = Get-ChildItem -Path $script:LogDir -Filter '*_powershell_*.log' -ErrorAction SilentlyContinue
        $logFiles | Should -BeNullOrEmpty
    }
}

Describe "Move-ImageFileToBatch — error log path derivation" {
    BeforeEach {
        $script:TmpRoot = Join-Path ([IO.Path]::GetTempPath()) "MIFTBErrTest_$([guid]::NewGuid())"
        $script:Src    = Join-Path $script:TmpRoot 'src'
        $script:Dst    = Join-Path $script:TmpRoot 'dst'
        $script:LogDir = Join-Path $script:TmpRoot 'logs'
        New-Item -Path $script:Src -ItemType Directory -Force | Out-Null
        New-Item -Path $script:Dst -ItemType Directory -Force | Out-Null
        New-Item -Path $script:LogDir -ItemType Directory -Force | Out-Null

        # Create a file that will trigger a copy error (read-only destination dir)
        $f = Join-Path $script:Src 'imgSample.jpg'
        [IO.File]::WriteAllText($f, 'fake')
    }

    AfterEach {
        if (Test-Path $script:TmpRoot) { Remove-Item $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "Write-RunSummary derives error log inside -LogDirectory, not as a literal file" {
        # Verify Write-RunSummary joins a filename onto LogDirectory
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        # The function should construct a path using Join-Path + $LogDirectory, not use $LogDirectory directly as a file
        $content | Should -Match 'Join-Path.*LogDirectory.*Move-ImageFileToBatch_errors'
    }

    It "Error log file created under -LogDirectory when errors occur" {
        # Make the destination read-only so Copy-Item fails (triggers error log)
        $roDir = Join-Path $script:Dst 'ro'
        New-Item -Path $roDir -ItemType Directory -Force | Out-Null
        # Simulate by passing a non-writable DestDir path (use a file as DestDir to provoke error)
        $fakeDestFile = Join-Path $script:TmpRoot 'notadir.txt'
        [IO.File]::WriteAllText($fakeDestFile, 'x')

        & $script:PS -NonInteractive -NoProfile -File $script:ScriptPath `
            -SourceDir $script:Src -DestDir $fakeDestFile -LogDirectory $script:LogDir 2>&1 | Out-Null

        $errLogs = Get-ChildItem -Path $script:LogDir -Filter 'Move-ImageFileToBatch_errors_*.log' -ErrorAction SilentlyContinue
        $errLogs | Should -Not -BeNullOrEmpty
    }
}
