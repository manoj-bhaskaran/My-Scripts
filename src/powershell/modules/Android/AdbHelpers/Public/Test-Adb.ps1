function Test-Adb {
    <#
.SYNOPSIS
    Verifies adb.exe is available in PATH.
.DESCRIPTION
    Uses Get-Command to locate 'adb'. Throws a terminating error if not found.
.OUTPUTS
    None. Throws on failure.
.NOTES
    Install Android SDK Platform-Tools and add its folder to PATH.
#>
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adb) {
        throw 'adb.exe not found. Install Platform-Tools and add to PATH.'
    }
}
