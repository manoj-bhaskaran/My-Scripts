function Resolve-MoveTarget {
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$Zip,
        [Parameter(Mandatory)][string]$Parent,
        [Parameter(Mandatory)][ValidateSet('Skip', 'Overwrite', 'Rename')][string]$CollisionPolicy
    )
    $target = Join-Path $Parent $Zip.Name
    $policyTag = 'None'
    if ([System.IO.File]::Exists($target)) {
        $policyTag = $CollisionPolicy
        if ($CollisionPolicy -eq 'Skip') { Write-LogDebug "Move skip (collision): '$($Zip.Name)' already exists in parent." }
        elseif ($CollisionPolicy -eq 'Rename') { $target = Resolve-UniquePath -Path $target }
    }
    [pscustomobject]@{ TargetPath = $target; PolicyTag = $policyTag }
}
