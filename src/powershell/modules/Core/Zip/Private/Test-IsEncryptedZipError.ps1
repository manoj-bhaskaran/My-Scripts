<#
.SYNOPSIS
    Returns $true when an exception or message indicates archive encryption / password protection.
.DESCRIPTION
    Walks the full exception chain (InnerException) looking for keywords that signal an encrypted
    or password-protected archive. Accepts an ErrorRecord, an Exception, or a plain string.
.PARAMETER ErrorObject
    The error to inspect: an ErrorRecord, an Exception, or any object whose string representation
    is checked against the encryption pattern.
#>
function Test-IsEncryptedZipError {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$ErrorObject)

    $encryptionPattern = '(?i)encrypt(?:ed|ion)?|password|protected|unsupported compression method'

    if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
        if ($ErrorObject.Exception -and (Test-IsEncryptedZipError -ErrorObject $ErrorObject.Exception)) {
            return $true
        }
        if ([string]$ErrorObject -match $encryptionPattern) { return $true }
        return $false
    }

    if ($ErrorObject -is [System.Exception]) {
        $ex = [System.Exception]$ErrorObject
        while ($null -ne $ex) {
            if (($ex.Message ?? '') -match $encryptionPattern) { return $true }
            $ex = $ex.InnerException
        }
        return $false
    }

    return ([string]$ErrorObject -match $encryptionPattern)
}
