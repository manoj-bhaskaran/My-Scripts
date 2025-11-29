# Private: path helpers (no exports)
function Resolve-VideoPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if ($IsWindows) { return $full.ToLowerInvariant() } else { return $full }
}
