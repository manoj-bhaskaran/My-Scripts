function Resolve-UniquePathCore {
    <#
    .SYNOPSIS
        Internal helper that generates a unique path variant by appending a timestamp suffix.

    .DESCRIPTION
        Used internally by Resolve-UniquePath and Resolve-UniqueDirectoryPath to create
        a unique path when a collision (path already exists) is detected.

        Appends a suffix of the form _yyyyMMddHHmmss or _yyyyMMddHHmmss_N to the base name,
        testing each variant until an unused path is found.

    .PARAMETER Path
        The path (file or directory) that already exists and needs a unique variant.

    .PARAMETER IsDirectory
        If $true, treats the path as a directory name.
        If $false, treats the path as a filename and preserves the extension.

    .OUTPUTS
        [string] A unique path variant that does not exist on the filesystem.

    .NOTES
        This is a private helper function. Direct use is not recommended;
        use Resolve-UniquePath or Resolve-UniqueDirectoryPath instead.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [bool]$IsDirectory
    )

    $parent = Split-Path -Path $Path -Parent
    $leaf = Split-Path -Path $Path -Leaf
    $base = if ($IsDirectory) { $leaf } else { [System.IO.Path]::GetFileNameWithoutExtension($leaf) }
    $ext = if ($IsDirectory) { '' } else { [System.IO.Path]::GetExtension($leaf) }
    $stamp = (Get-Date -Format 'yyyyMMddHHmmss')
    $i = 0
    $maxAttempts = 1000

    do {
        if ($i -ge $maxAttempts) {
            throw "Resolve-UniquePathCore: exceeded $maxAttempts attempts finding a unique path for '$Path'. Test-Path may be mocked or the directory has an unexpected number of collisions."
        }
        $suffix = if ($i -eq 0) { "_$stamp" } else { "_$stamp`_$i" }
        $candidate = Join-Path $parent ($base + $suffix + $ext)
        Write-Host "[DIAG-RUPC] attempt $i candidate='$candidate' exists=$(Test-Path -LiteralPath $candidate)" -ForegroundColor DarkYellow
        $i++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}
