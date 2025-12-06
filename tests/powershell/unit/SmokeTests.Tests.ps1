# Smoke tests to validate that PowerShell scripts parse without syntax errors.

BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    $script:Scripts = Get-ChildItem -Path (Join-Path $repoRoot 'src' 'powershell') -Recurse -Filter '*.ps1' |
        Where-Object { $_.FullName -notmatch '[/\\]modules[/\\]' }
}

Describe "Script Smoke Tests" {
    foreach ($script in $script:Scripts) {
        Context $script.Name {
            It "Script syntax is valid" {
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize(
                    (Get-Content $script.FullName -Raw), [ref]$errors
                )
                $errors.Count | Should -Be 0
            }
        }
    }
}
