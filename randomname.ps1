# Function to generate a random file name
function Get-RandomFileName {
    # Exclude problematic characters: \ / : * ? " < > | and others that might cause issues.
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789~!@$()_-+=QWERTYUIOPASDFGHJKLZXCVBNM'
    $namelen = Get-Random -Maximum 32 -Minimum 4
    $randomName = -join ((0..$namelen) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

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
