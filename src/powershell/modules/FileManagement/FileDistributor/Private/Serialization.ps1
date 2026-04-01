# Function to extract paths from items
function ConvertItemsToPaths {
    param ([array]$Items)

    LogMessage -Message "DEBUG: ConvertItemsToPaths - Input count: $(if ($Items) { $Items.Count } else { '0 (null)' })" -IsDebug

    if (-not $Items) {
        LogMessage -Message "DEBUG: ConvertItemsToPaths - Returning empty array (null input)" -IsDebug
        return @()
    }

    $out = @()
    $index = 0
    foreach ($i in $Items) {
        $index++

        if ($null -eq $i) {
            LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index is null, skipping" -IsDebug
            continue
        }

        $itemType = $i.GetType().Name
        LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index type is $itemType" -IsDebug

        if ($i -is [System.IO.FileSystemInfo]) {
            if ($i.FullName) {
                $fullPath = $i.FullName
                if (-not [string]::IsNullOrWhiteSpace($fullPath)) {
                    LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index converting '$($i.Name)' to '$fullPath'" -IsDebug
                    $out += $fullPath
                }
                else {
                    LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index has whitespace-only FullName for '$($i.Name)'" -IsDebug
                }
            }
            else {
                LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index has no FullName property for '$($i.Name)'"
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$i)) {
            LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index is string '$i'" -IsDebug
            $out += [string]$i
        }
        else {
            LogMessage -Message "DEBUG: ConvertItemsToPaths - Item $index skipped (empty/whitespace)"
        }
    }

    LogMessage -Message "DEBUG: ConvertItemsToPaths - Output count: $($out.Count)" -IsDebug
    return $out
}

# Function to convert paths to items
function ConvertPathsToItems {
    param ([array]$Paths)

    LogMessage -Message "DEBUG: ConvertPathsToItems - Input count: $(if ($Paths) { $Paths.Count } else { '0 (null)' })" -IsDebug

    if (-not $Paths) {
        LogMessage -Message "DEBUG: ConvertPathsToItems - Returning empty array (null input)" -IsDebug
        return @()
    }

    $out = @()
    $index = 0
    foreach ($path in $Paths) {
        $index++

        if ([string]::IsNullOrWhiteSpace($path)) {
            LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index is null/whitespace, skipping" -IsDebug
            continue
        }

        LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index processing path '$path'" -IsDebug

        try {
            $item = Get-Item -LiteralPath $path -ErrorAction Stop
            if ($item -and $item.FullName -and -not [string]::IsNullOrWhiteSpace($item.FullName)) {
                LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index successfully converted to $($item.GetType().Name)"
                $out += $item
            }
            else {
                LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index has invalid FullName after Get-Item"
            }
        }
        catch {
            LogMessage -Message "DEBUG: ConvertPathsToItems - Item $index failed to convert '$path' - $($_.Exception.Message)" -IsWarning
        }
    }

    LogMessage -Message "DEBUG: ConvertPathsToItems - Output count: $($out.Count)"
    return $out
}
