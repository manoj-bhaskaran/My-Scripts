function Get-RemoteFileCount {
    <#
.SYNOPSIS
    Returns a best-effort file count for a remote path on the device.
.DESCRIPTION
    Uses find and wc -l via native, toybox, or busybox commands. Uses Invoke-AdbSh to avoid device shell line-ending issues.
.PARAMETER RemoteParent
    Parent directory on the device.
.PARAMETER RemoteLeaf
    Leaf file or directory name on the device.
.PARAMETER DebugMode
    Enables debug logging for the remote shell probe.
.PARAMETER DebugLog
    Optional log file path used when DebugMode is enabled.
.OUTPUTS
    [Int64] file count (0 if unavailable).
#>
    param(
        [string]$RemoteParent,
        [string]$RemoteLeaf,
        [switch]$DebugMode,
        [string]$DebugLog
    )

    $remotePath = "$RemoteParent/$RemoteLeaf"
    $script = @'
path="__REMOTE_PATH__"
if command -v find >/dev/null 2>&1; then
  find "$path" -type f 2>/dev/null | wc -l
elif command -v toybox >/dev/null 2>&1; then
  toybox find "$path" -type f 2>/dev/null | wc -l
elif command -v busybox >/dev/null 2>&1; then
  busybox find "$path" -type f 2>/dev/null | wc -l
else
  echo 0
fi
'@
    $cmd = $script.Replace('__REMOTE_PATH__', $remotePath)

    try {
        $out = Invoke-AdbSh -Script $cmd -DebugMode:$DebugMode -DebugLog $DebugLog
        if ([string]::IsNullOrWhiteSpace($out)) {
            return 0
        }

        $count = 0L
        [void][int64]::TryParse($out.Trim(), [ref]$count)
        return $count
    } catch {
        return 0
    }
}
