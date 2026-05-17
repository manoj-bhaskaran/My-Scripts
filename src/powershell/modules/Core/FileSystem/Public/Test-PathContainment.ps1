function Test-PathContainment {
    <#
    .SYNOPSIS
        Tests whether a candidate path is located inside a container directory.

    .DESCRIPTION
        Normalises both paths with a trailing platform separator (via Add-TrailingSeparator)
        and performs a case-insensitive ordinal prefix comparison, so the check is both
        cross-platform and resistant to false positives from shared path prefixes
        (e.g. C:\Foo is not considered to contain C:\FooBar).

    .PARAMETER Container
        The directory that may contain the candidate path.

    .PARAMETER Candidate
        The path to test for containment inside Container.

    .EXAMPLE
        Test-PathContainment -Container 'C:\Source' -Candidate 'C:\Source\Sub'
        Returns $true.

    .EXAMPLE
        Test-PathContainment -Container 'C:\Source' -Candidate 'C:\SourceExtra'
        Returns $false (shared prefix but not contained).

    .OUTPUTS
        [bool] True if Candidate is inside Container, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Container,

        [Parameter(Mandatory)]
        [string]$Candidate
    )

    $containerWithSep = Add-TrailingSeparator -Path $Container
    $candidateWithSep = Add-TrailingSeparator -Path $Candidate
    return $candidateWithSep.StartsWith($containerWithSep, [System.StringComparison]::OrdinalIgnoreCase)
}
