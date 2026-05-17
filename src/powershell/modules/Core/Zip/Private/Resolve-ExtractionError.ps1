<#
.SYNOPSIS
    Throws a normalized extraction error, surfacing a clear encrypted-archive message when applicable.
.DESCRIPTION
    Passes the ErrorRecord through Test-IsEncryptedZipError. If encryption is detected, throws a
    user-friendly message that includes the zip path; otherwise re-throws the original ErrorRecord.
.PARAMETER ZipPath
    Path to the zip archive that triggered the error.
.PARAMETER ErrorRecord
    The caught ErrorRecord from the extraction attempt.
#>
function Resolve-ExtractionError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    if (Test-IsEncryptedZipError -ErrorObject $ErrorRecord) {
        throw "Extraction failed for '$ZipPath' (zip may be encrypted): $($ErrorRecord.Exception.Message)"
    }
    throw $ErrorRecord
}
