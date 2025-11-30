function Get-RandomFileName {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 255)]
        [int]$MinimumLength = 4,
        [ValidateRange(1, 255)]
        [int]$MaximumLength = 32,
        [ValidateRange(1, 100000)]
        [int]$MaxAttempts = 100
    )

    # Validate parameters
    if ($MaximumLength -lt $MinimumLength) {
        throw "MaximumLength must be greater than or equal to MinimumLength."
    }

    # Allow-lists
    $firstCharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $restCharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-~'

    # Windows reserved device names (base name only, case-insensitive)
    $reservedRegex = '^(?i:(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]))$'

    $attempt = 0
    do {
        $attempt++
        $namelen = Get-Random -Minimum $MinimumLength -Maximum ($MaximumLength + 1)

        # Always start with an alphanumeric
        $sb = [System.Text.StringBuilder]::new()
        $null = $sb.Append($firstCharSet[(Get-Random -Maximum $firstCharSet.Length)])

        # Fill the remainder from the broader allow-list
        for ($i = 1; $i -lt $namelen; $i++) {
            $null = $sb.Append($restCharSet[(Get-Random -Maximum $restCharSet.Length)])
        }

        $randomName = $sb.ToString()

        if ($randomName -match $reservedRegex) {
            if ($attempt -ge $MaxAttempts) {
                # Force a non-reserved name by changing the first character
                $replacement = $firstCharSet[(Get-Random -Maximum $firstCharSet.Length)]
                if ($replacement -eq $randomName[0]) {
                    # ensure change
                    $replacement = $firstCharSet[(Get-Random -Maximum $firstCharSet.Length)]
                }
                $randomName = $replacement + $randomName.Substring(1)
                break
            }
            continue
        }
        else {
            break
        }
    } while ($true)

    return $randomName
}
