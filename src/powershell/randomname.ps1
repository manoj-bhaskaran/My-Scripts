<#
.SYNOPSIS
Generates a random file name using a conservative, Windows-safe allow-list.
Accepts parameters for the minimum and maximum lengths of the file name.

.DESCRIPTION
Builds a name from an allow-list that avoids Windows invalid filename characters
(`< > : " / \ | ? *`) and shell-sensitive punctuation. The first character is
restricted to alphanumerics; subsequent characters may include `_`, `-`, or `~`.
Names are additionally validated to avoid Windows reserved device names
(`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`, case-insensitive).
Randomness uses `Get-Random` (not cryptographically secure).

.PARAMETER MinimumLength
Optional. Maximum length of the generated file name. Defaults to 32.
Must be between 1 and 255 and >= MinimumLength.

.PARAMETER MaximumLength
Optional. Specifies the maximum length of the generated file name. Defaults to 32. Must be greater than or equal to the MinimumLength.

.EXAMPLE
Generate a random file name with default length range:

.EXAMPLE
Generate a random file name with a custom length range:
Get-RandomFileName -MinimumLength 5 -MaximumLength 15

.NOTES
Script Workflow:
1. **Parameter Validation**:
   - Validates that `MinimumLength` and `MaximumLength` are within 1..255.
   - Validates that `MaximumLength` is greater than or equal to `MinimumLength`

2. **Character Set Definition**:
   - Uses an allow-list:
     - First character: `A–Z`, `a–z`, `0–9`
     - Remaining characters: `A–Z`, `a–z`, `0–9`, `_`, `-`, `~`

3. **Random Name Generation**:
   - Randomly selects the length of the file name within the specified range.
   - Generates the name from the allow-list and rejects Windows reserved names.

4. **Reserved Name Check**:
   - Regenerates if the random name matches a Windows reserved device name.

Limitations:
- Randomness is suitable for uniqueness, not for cryptographic security.
- The generator returns a base name only (no extension).

.VERSION
2.0.0

CHANGELOG
## 2.0.0 — 2025-09-14
### Added
- Validation to avoid Windows reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1–9`, `LPT1–9`, case-insensitive).
### Changed (breaking)
- First character must be alphanumeric; removed previous special-case parenthesis handling.
- Tightened allow-list to alphanumerics plus `_`, `-`, `~` (subsequent characters only).
### Improved
- Parameter validation using `[ValidateRange(1,255)]` on `MinimumLength` and `MaximumLength`, plus runtime check that `MaximumLength >= MinimumLength`.
- Documentation updated (.EXAMPLE blocks, clarify non-crypto RNG, list allow-list and reserved name handling).
#>

# Function to generate a random file name
function Get-RandomFileName {
    [CmdletBinding()]
    param(
        [ValidateRange(1,255)]
        [int]$MinimumLength = 4,
        [ValidateRange(1,255)]
        [int]$MaximumLength = 32
    )

    # Validate parameters
    if ($MaximumLength -lt $MinimumLength) {
        throw "MaximumLength must be greater than or equal to MinimumLength."
    }

    # Allow-lists
    $firstCharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $restCharSet  = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-~'

    # Windows reserved device names (base name only, case-insensitive)
    $reservedRegex = '^(?i:(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]))$'

    do {
        $namelen = Get-Random -Minimum $MinimumLength -Maximum ($MaximumLength + 1)

        # Always start with an alphanumeric
        $sb = [System.Text.StringBuilder]::new()
        $null = $sb.Append($firstCharSet[(Get-Random -Maximum $firstCharSet.Length)])

        # Fill the remainder from the broader allow-list
        for ($i = 1; $i -lt $namelen; $i++) {
            $null = $sb.Append($restCharSet[(Get-Random -Maximum $restCharSet.Length)])
        }

        $randomName = $sb.ToString()
        # Regenerate if the name is a reserved Windows device name
    } while ($randomName -match $reservedRegex)

    return $randomName
}
