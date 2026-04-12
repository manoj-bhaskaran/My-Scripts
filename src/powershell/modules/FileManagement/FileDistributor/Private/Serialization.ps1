# Function to extract paths from items
function Convert-RunStateToSerializableHashtable {
    param(
        [Parameter(Mandatory = $true)][FileDistributorRunState]$RunState
    )

    return $RunState.ToSerializableHashtable()
}

# Function to extract paths from items
function ConvertItemsToPaths {
    param ([array]$Items)

    Write-LogDebug "DEBUG: ConvertItemsToPaths - Input count: $(if ($Items) { $Items.Count } else { '0 (null)' })"

    if (-not $Items) {
        Write-LogDebug "DEBUG: ConvertItemsToPaths - Returning empty array (null input)"
        return @()
    }

    $out = @()
    $index = 0
    foreach ($i in $Items) {
        $index++

        if ($null -eq $i) {
            Write-LogDebug "DEBUG: ConvertItemsToPaths - Item $index is null, skipping"
            continue
        }

        $itemType = $i.GetType().Name
        Write-LogDebug "DEBUG: ConvertItemsToPaths - Item $index type is $itemType"

        if ($i -is [System.IO.FileSystemInfo]) {
            if ($i.FullName) {
                $fullPath = $i.FullName
                if (-not [string]::IsNullOrWhiteSpace($fullPath)) {
                    Write-LogDebug "DEBUG: ConvertItemsToPaths - Item $index converting '$($i.Name)' to '$fullPath'"
                    $out += $fullPath
                } else {
                    Write-LogDebug "DEBUG: ConvertItemsToPaths - Item $index has whitespace-only FullName for '$($i.Name)'"
                }
            } else {
                Write-LogDebug "DEBUG: ConvertItemsToPaths - Item $index has no FullName property for '$($i.Name)'"
            }
        } elseif (-not [string]::IsNullOrWhiteSpace([string]$i)) {
            Write-LogDebug "DEBUG: ConvertItemsToPaths - Item $index is string '$i'"
            $out += [string]$i
        } else {
            Write-LogDebug "DEBUG: ConvertItemsToPaths - Item $index skipped (empty/whitespace)"
        }
    }

    Write-LogDebug "DEBUG: ConvertItemsToPaths - Output count: $($out.Count)"
    return $out
}

# Function to convert paths to items
function ConvertPathsToItems {
    param ([array]$Paths)

    Write-LogDebug "DEBUG: ConvertPathsToItems - Input count: $(if ($Paths) { $Paths.Count } else { '0 (null)' })"

    if (-not $Paths) {
        Write-LogDebug "DEBUG: ConvertPathsToItems - Returning empty array (null input)"
        return @()
    }

    $out = @()
    $index = 0
    foreach ($path in $Paths) {
        $index++

        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-LogDebug "DEBUG: ConvertPathsToItems - Item $index is null/whitespace, skipping"
            continue
        }

        Write-LogDebug "DEBUG: ConvertPathsToItems - Item $index processing path '$path'"

        try {
            $item = Get-Item -LiteralPath $path -ErrorAction Stop
            if ($item -and $item.FullName -and -not [string]::IsNullOrWhiteSpace($item.FullName)) {
                Write-LogDebug "DEBUG: ConvertPathsToItems - Item $index successfully converted to $($item.GetType().Name)"
                $out += $item
            } else {
                Write-LogDebug "DEBUG: ConvertPathsToItems - Item $index has invalid FullName after Get-Item"
            }
        } catch {
            Write-LogWarning "DEBUG: ConvertPathsToItems - Item $index failed to convert '$path' - $($_.Exception.Message)"
        }
    }

    Write-LogDebug "DEBUG: ConvertPathsToItems - Output count: $($out.Count)"
    return $out
}
