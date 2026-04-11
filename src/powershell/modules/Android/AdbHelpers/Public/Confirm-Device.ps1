function Confirm-Device {
    <#
.SYNOPSIS
    Confirms an authorized Android device is connected.
.DESCRIPTION
    Runs 'adb devices' and checks for a line ending with 'device'. If the device shows 'unauthorized' or nothing, throws guidance.
.OUTPUTS
    None. Throws on failure.
.NOTES
    Ensure the phone is unlocked and USB debugging is enabled and authorized.
#>
    $out = adb devices | Select-String "device`$"
    if (-not $out) {
        throw 'No authorized device. Check cable, unlock phone, enable USB debugging, and allow this PC.'
    }
}
