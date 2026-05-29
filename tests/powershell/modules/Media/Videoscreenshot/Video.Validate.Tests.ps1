<#
.SYNOPSIS
Pester tests for Test-VideoPlayable (Video.Validate.ps1).
#>

BeforeAll {
    $script:ValidatePath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'Media' 'Videoscreenshot' 'Private' 'Video.Validate.ps1'

    if (-not (Test-Path -LiteralPath $script:ValidatePath)) {
        throw "Required file not found: $script:ValidatePath"
    }

    . $script:ValidatePath

    function Script:New-TempVideoFile {
        $tmpBase = [System.IO.Path]::GetTempFileName()
        $dest = [System.IO.Path]::ChangeExtension($tmpBase, '.mp4')
        Move-Item -LiteralPath $tmpBase -Destination $dest -Force
        Set-Content -LiteralPath $dest -Value 'fake video' -NoNewline
        $dest
    }

    function Script:New-FakeVlcExecutable {
        param(
            [Parameter(Mandatory)][string]$UnixBody,
            [Parameter(Mandatory)][string]$WindowsBody
        )

        $extension = if ($IsWindows) { '.cmd' } else { '.sh' }
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ("fake-vlc-{0}{1}" -f [System.Guid]::NewGuid().ToString('N'), $extension)
        if ($IsWindows) {
            Set-Content -LiteralPath $path -Value "@echo off`r`n$WindowsBody" -NoNewline
        }
        else {
            Set-Content -LiteralPath $path -Value "#!/usr/bin/env bash`n$UnixBody" -NoNewline
            chmod +x $path
        }
        $path
    }
}

Describe 'Test-VideoPlayable' {
    BeforeEach {
        $script:FakeVideo = Script:New-TempVideoFile
        $script:FakeVlc = $null
    }

    AfterEach {
        foreach ($path in @($script:FakeVideo, $script:FakeVlc)) {
            if ($path -and (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'returns true when the VLC probe exits successfully' {
        $script:FakeVlc = Script:New-FakeVlcExecutable -UnixBody 'exit 0' -WindowsBody 'exit /b 0'

        Test-VideoPlayable -Path $script:FakeVideo -VlcExe $script:FakeVlc -TimeoutSeconds 2 | Should -BeTrue
    }

    It 'returns false when the VLC probe exits with a non-zero code' {
        $script:FakeVlc = Script:New-FakeVlcExecutable -UnixBody 'echo probe failed >&2; exit 7' -WindowsBody 'echo probe failed 1>&2& exit /b 7'

        Test-VideoPlayable -Path $script:FakeVideo -VlcExe $script:FakeVlc -TimeoutSeconds 2 | Should -BeFalse
    }

    It 'force-kills a hung VLC probe and treats the video as not playable' {
        $script:FakeVlc = Script:New-FakeVlcExecutable -UnixBody 'sleep 60' -WindowsBody 'timeout /t 60 /nobreak >NUL'

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Test-VideoPlayable -Path $script:FakeVideo -VlcExe $script:FakeVlc -TimeoutSeconds 1
        $sw.Stop()

        $result | Should -BeFalse
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 10
    }
}
