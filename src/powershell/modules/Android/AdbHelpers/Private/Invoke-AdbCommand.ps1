function Invoke-AdbCommand {
    <#
.SYNOPSIS
    Invokes adb with passthrough arguments.
.DESCRIPTION
    Thin wrapper around the adb executable to keep external process invocation mockable in tests.
#>
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$Arguments
    )

    & adb @Arguments
}
