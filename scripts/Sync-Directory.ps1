param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    # If set, only show what *would* happen, don't change anything
    [switch]$PreviewOnly
)

# Resolve and normalise paths
$Source = (Resolve-Path -Path $Source).ProviderPath.TrimEnd('\')
$Destination = (Resolve-Path -Path $Destination).ProviderPath.TrimEnd('\')

Write-Host "Source     : $Source"
Write-Host "Destination: $Destination"
Write-Host ""

# Get all files from both trees
$srcFiles = Get-ChildItem -Path $Source      -Recurse -File
$dstFiles = Get-ChildItem -Path $Destination -Recurse -File

# Index by relative path (same key for source & destination)
$srcIndex = @{}
foreach ($f in $srcFiles) {
    $rel = $f.FullName.Substring($Source.Length).TrimStart('\')
    $srcIndex[$rel] = $f
}

$dstIndex = @{}
foreach ($f in $dstFiles) {
    $rel = $f.FullName.Substring($Destination.Length).TrimStart('\')
    $dstIndex[$rel] = $f
}

$toCopyNew = New-Object System.Collections.Generic.List[object]
$toCopyUpdates = New-Object System.Collections.Generic.List[object]
$toDelete = New-Object System.Collections.Generic.List[object]

# Determine new and updated files (Source → Destination)
foreach ($relPath in $srcIndex.Keys) {
    $srcFile = $srcIndex[$relPath]
    if (-not $dstIndex.ContainsKey($relPath)) {
        # Exists only in source → new file to copy
        $toCopyNew.Add([PSCustomObject]@{
                RelativePath = $relPath
                Source       = $srcFile
            })
    }
    else {
        $dstFile = $dstIndex[$relPath]
        # Compare by LastWriteTimeUtc and length (simple heuristic)
        if ($srcFile.LastWriteTimeUtc -ne $dstFile.LastWriteTimeUtc -or
            $srcFile.Length -ne $dstFile.Length) {

            $toCopyUpdates.Add([PSCustomObject]@{
                    RelativePath = $relPath
                    Source       = $srcFile
                    Destination  = $dstFile
                })
        }
    }
}

# Determine files present only in Destination → candidates for deletion
foreach ($relPath in $dstIndex.Keys) {
    if (-not $srcIndex.ContainsKey($relPath)) {
        $toDelete.Add([PSCustomObject]@{
                RelativePath = $relPath
                Destination  = $dstIndex[$relPath]
            })
    }
}

Write-Host "Planned actions:"
Write-Host "  New files     to copy : $($toCopyNew.Count)"
Write-Host "  Updated files to copy : $($toCopyUpdates.Count)"
Write-Host "  Extra files   to delete: $($toDelete.Count)"
Write-Host ""

if ($PreviewOnly) {
    Write-Host "Preview only mode - no changes will be made."
    Write-Host ""

    if ($toCopyNew.Count -gt 0) {
        Write-Host "=== New files to be copied ==="
        $toCopyNew | ForEach-Object {
            Write-Host "[NEW]     $($_.RelativePath)"
        }
        Write-Host ""
    }

    if ($toCopyUpdates.Count -gt 0) {
        Write-Host "=== Files to be updated ==="
        $toCopyUpdates | ForEach-Object {
            Write-Host "[UPDATE]  $($_.RelativePath)"
        }
        Write-Host ""
    }

    if ($toDelete.Count -gt 0) {
        Write-Host "=== Files that would be deleted from Destination ==="
        $toDelete | ForEach-Object {
            Write-Host "[DELETE]  $($_.RelativePath)"
        }
        Write-Host ""
    }

    return
}

###############################################################################
# 1. Copy new files
###############################################################################
foreach ($item in $toCopyNew) {
    $rel = $item.RelativePath
    $srcFile = $item.Source
    $dstPath = Join-Path -Path $Destination -ChildPath $rel

    $dstDir = Split-Path -Path $dstPath -Parent
    if (-not (Test-Path -Path $dstDir)) {
        New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
    }

    Write-Host "[COPY NEW] $rel"
    Copy-Item -Path $srcFile.FullName -Destination $dstPath -Force
}

###############################################################################
# 2. Copy updated files
###############################################################################
foreach ($item in $toCopyUpdates) {
    $rel = $item.RelativePath
    $srcFile = $item.Source
    $dstPath = $item.Destination.FullName

    Write-Host "[COPY UPDATE] $rel"
    Copy-Item -Path $srcFile.FullName -Destination $dstPath -Force
}

###############################################################################
# 3. Delete extra files from Destination (with confirmation per file)
###############################################################################
foreach ($item in $toDelete) {
    $rel = $item.RelativePath
    $dstFile = $item.Destination

    Write-Host "[DELETE CANDIDATE] $rel"
    # -Confirm with no value forces a prompt before deletion
    Remove-Item -Path $dstFile.FullName -Force -Confirm
}

Write-Host ""
Write-Host "Sync complete."
