function Test-PhoneTar {
    <#
.SYNOPSIS
    Verifies phone-side tar availability for tar mode.
.PARAMETER Mode
    Transfer mode. When not Tar, the check is skipped.
.PARAMETER DebugMode
    Enables debug logging for the remote shell probe.
.PARAMETER DebugLog
    Optional log file path used when DebugMode is enabled.
.OUTPUTS
    None. Throws on failure if tar mode is requested and tar is unavailable on the device.
#>
    param(
        [ValidateSet('Pull', 'Tar')]
        [string]$Mode = 'Tar',

        [switch]$DebugMode,

        [string]$DebugLog
    )

    if ($Mode -ne 'Tar') {
        return
    }

    $script = @'
if command -v tar >/dev/null 2>&1; then
  tar --help >/dev/null 2>&1 || true
  echo 0
elif command -v toybox >/dev/null 2>&1 && toybox tar --help >/dev/null 2>&1; then
  echo 0
elif command -v busybox >/dev/null 2>&1 && busybox tar --help >/dev/null 2>&1; then
  echo 0
else
  echo 1
fi
'@

    $rc = (Invoke-AdbSh -Script $script -DebugMode:$DebugMode -DebugLog $DebugLog).Trim()
    if ([string]::IsNullOrEmpty($rc)) {
        throw 'Phone-side tar check failed (no response). Reconnect the device and try again.'
    }

    if ($rc -ne '0') {
        throw 'Phone-side tar not found. Switch to pull mode (use -Resume instead of tar-mode parameters).'
    }
}
