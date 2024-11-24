<#
.SYNOPSIS
This PowerShell script generates a random file name, excluding characters that might cause issues. It accepts parameters for the minimum and maximum lengths of the file name.

.DESCRIPTION
The script generates a random file name by selecting random characters from a defined set, ensuring that problematic characters like \ / : * ? " < > | are excluded. The length of the generated name is random within the specified range provided by the parameters. If the first character is a problematic parenthesis, it is replaced with another random character from the filtered set.

.PARAMETER MinimumLength
Optional. Specifies the minimum length of the generated file name. Defaults to 4. Must be greater than 0.

.PARAMETER MaximumLength
Optional. Specifies the maximum length of the generated file name. Defaults to 32. Must be greater than or equal to the MinimumLength.

.EXAMPLES
To generate a random file name with default length range:
Get-RandomFileName

To generate a random file name with a custom length range:
Get-RandomFileName -MinimumLength 5 -MaximumLength 15

.NOTES
Script Workflow:
1. **Parameter Validation**:
   - Validates that `MinimumLength` is greater than 0.
   - Validates that `MaximumLength` is greater than or equal to `MinimumLength`.

2. **Character Set Definition**:
   - Defines a set of characters to be used for generating the random file name, excluding problematic characters.

3. **Random Name Generation**:
   - Randomly selects the length of the file name within the specified range.
   - Randomly generates the file name by selecting characters from the defined set.

4. **First Character Check**:
   - Checks if the first character is a problematic parenthesis.
   - If so, replaces it with another random character from the filtered set.

Limitations:
- The generated file name does not include some special characters that might be safe but are excluded for simplicity.
#>

# Function to generate a random file name
function Get-RandomFileName {
    param(
        [int]$MinimumLength = 4,
        [int]$MaximumLength = 32
    )

    # Validate parameters
    if ($MinimumLength -le 0) {
        throw "MinimumLength must be greater than 0."
    }
    if ($MaximumLength -lt $MinimumLength) {
        throw "MaximumLength must be greater than or equal to MinimumLength."
    }

    # Exclude problematic characters: \ / : * ? " < > | and others that might cause issues.
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789~!@$()_-+=QWERTYUIOPASDFGHJKLZXCVBNM'
    $namelen = Get-Random -Minimum $MinimumLength -Maximum ($MaximumLength + 1)
    $randomName = -join ((0..($namelen-1)) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

    if ($randomName[0] -eq '(' -or $randomName[0] -eq ')') {
        # Filter out '(' from the available characters
        $filteredChars = $chars -replace '[()]'
        # Select a random character that is not '('
        $newFirstChar = $filteredChars[(Get-Random -Maximum $filteredChars.Length)]
        # Replace the first character with the new one
        $randomName = $newFirstChar + $randomName.Substring(1)
    }
    return $randomName
}
