function Get-RemoteSize {
    <#
.SYNOPSIS
    Returns total bytes for a remote path on the device.
.DESCRIPTION
    Prefers du, then falls back to summing file sizes via stat in a find loop. Uses Invoke-AdbSh to avoid device shell line-ending issues.
.PARAMETER RemoteParent
    Parent directory on the device.
.PARAMETER RemoteLeaf
    Leaf file or directory name on the device.
.PARAMETER DebugMode
    Enables debug logging for the remote shell probe.
.PARAMETER DebugLog
    Optional log file path used when DebugMode is enabled.
.OUTPUTS
    [Int64] total size in bytes (0 if unavailable).
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

if du -sb "$path" >/dev/null 2>&1; then
  set -- $(du -sb "$path"); echo "$1"; exit 0
fi
if command -v toybox >/dev/null 2>&1 && toybox du -b "$path" >/dev/null 2>&1; then
  set -- $(toybox du -b "$path"); echo "$1"; exit 0
fi
if command -v busybox >/dev/null 2>&1 && busybox du -s "$path" >/dev/null 2>&1; then
  set -- $(busybox du -s "$path"); echo $(( $1 * 1024 )); exit 0
fi

sum=0
if command -v stat >/dev/null 2>&1; then
  find "$path" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    sz=$(stat -c %s "$f" 2>/dev/null || echo 0)
    sum=$(( sum + ${sz:-0} ))
  done
  echo "$sum"; exit 0
fi

if command -v toybox >/dev/null 2>&1; then
  find "$path" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    sz=$(toybox stat -c %s "$f" 2>/dev/null || echo 0)
    sum=$(( sum + ${sz:-0} ))
  done
  echo "$sum"; exit 0
fi

if command -v busybox >/dev/null 2>&1; then
  find "$path" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    sz=$(busybox stat -c %s "$f" 2>/dev/null || echo 0)
    sum=$(( sum + ${sz:-0} ))
  done
  echo "$sum"; exit 0
fi

echo 0
'@
    $cmd = $script.Replace('__REMOTE_PATH__', $remotePath)

    try {
        $bytesText = Invoke-AdbSh -Script $cmd -DebugMode:$DebugMode -DebugLog $DebugLog
        if ([string]::IsNullOrWhiteSpace($bytesText)) {
            return 0
        }

        $bytes = 0L
        [void][int64]::TryParse($bytesText.Trim(), [ref]$bytes)
        return $bytes
    } catch {
        return 0
    }
}
