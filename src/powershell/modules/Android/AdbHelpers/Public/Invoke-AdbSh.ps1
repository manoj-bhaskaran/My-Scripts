function Invoke-AdbSh {
    <#
.SYNOPSIS
    Runs a shell script on the device safely from PowerShell.
.DESCRIPTION
    Normalizes line endings, filters blank lines, joins ordinary statements with '; ', and preserves newlines at POSIX shell control boundaries.
.PARAMETER Script
    The shell script text to execute on the device.
.PARAMETER DebugMode
    Enables lightweight debug logging of the generated shell command and stdout prefix.
.PARAMETER DebugLog
    Optional log file path used when DebugMode is enabled.
.OUTPUTS
    [string] Raw stdout from the device, or an empty string on error.
#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Script,

        [switch]$DebugMode,

        [string]$DebugLog
    )

    try {
        $norm = ($Script -replace "`r`n", "`n" -replace "`r", "`n").Trim()
        $lines = $norm -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

        $out = New-Object System.Text.StringBuilder
        $prev = $null
        foreach ($line in $lines) {
            $currStartsCtl = $line -match '^(elif|fi|done|esac|then|do|else)\b'
            $prevEndsCtl = $false
            if ($null -ne $prev) {
                $prevEndsCtl = $prev -match '\b(then|do|else)$'
            }

            if ($null -ne $prev) {
                if ($currStartsCtl -or $prevEndsCtl) {
                    [void]$out.Append("`n")
                } else {
                    [void]$out.Append('; ')
                }
            }

            [void]$out.Append($line)
            $prev = $line
        }

        $one = $out.ToString()

        if ($DebugMode -and $DebugLog) {
            Add-Content -Path $DebugLog -Value ("[{0}] adb shell << {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $one)
        }

        $result = adb shell $one

        if ($DebugMode -and $DebugLog) {
            $len = if ($result) { $result.Length } else { 0 }
            $prefix = if ($result -and $result.Length -gt 1000) { $result.Substring(0, 1000) + '...' } else { $result }
            Add-Content -Path $DebugLog -Value ("[{0}] stdout({1} chars): {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $len, $prefix)
        }

        return $result
    } catch {
        if ($DebugMode -and $DebugLog) {
            Add-Content -Path $DebugLog -Value ("[{0}] ERROR: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $_)
        }

        return ''
    }
}
