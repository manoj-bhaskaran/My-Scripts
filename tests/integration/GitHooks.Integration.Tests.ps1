[CmdletBinding()]
param()

Describe "Git Hook Integration" {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot ".." "..")
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("git_hooks_integration_{0}" -f ([guid]::NewGuid()))
        $script:repoPath = Join-Path $script:testRoot "repo"
        $script:stagingMirror = Join-Path $script:testRoot "staging"
        $script:deployBase = Join-Path $script:testRoot "modules"
        $script:moduleName = "IntegrationSample"
        $script:moduleVersion = "1.2.3"
        $script:moduleRelPath = "src\\powershell\\modules\\$($script:moduleName)\\$($script:moduleName).psm1"

        New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $script:repoPath -ItemType Directory -Force | Out-Null
        New-Item -Path $script:stagingMirror -ItemType Directory -Force | Out-Null
        New-Item -Path $script:deployBase -ItemType Directory -Force | Out-Null

        Copy-Item -Path (Join-Path $script:repoRoot "src/powershell/git") -Destination (Join-Path $script:repoPath "src/powershell") -Recurse -Force
        Copy-Item -Path (Join-Path $script:repoRoot "src/powershell/modules") -Destination (Join-Path $script:repoPath "src/powershell") -Recurse -Force

        $modulePath = Join-Path $script:repoPath $script:moduleRelPath
        New-Item -Path (Split-Path $modulePath -Parent) -ItemType Directory -Force | Out-Null
        @"
<#
Version: $($script:moduleVersion)
#>
function Get-IntegrationSample {
    [CmdletBinding()]
    param()
    "integration works"
}

Export-ModuleMember -Function Get-IntegrationSample
"@ | Set-Content -Path $modulePath -Encoding utf8

        $configDir = Join-Path $script:repoPath "config"
        New-Item -Path (Join-Path $configDir "modules") -ItemType Directory -Force | Out-Null

        $localConfig = @{ stagingMirror = $script:stagingMirror; enabled = $true } | ConvertTo-Json
        $localConfig | Set-Content -Path (Join-Path $configDir "local-deployment-config.json") -Encoding utf8

        $deploymentEntry = "$($script:moduleName)|$($script:moduleRelPath)|Alt:$($script:deployBase)|Integration Tester|Integration sample module"
        $deploymentEntry | Set-Content -Path (Join-Path $configDir "modules" "deployment.txt") -Encoding utf8

        Push-Location $script:repoPath
        git init -b main | Out-Null
        git config user.name "Integration Tester"
        git config user.email "integration@example.com"

        Copy-Item -Path (Join-Path $script:repoRoot "hooks" "post-commit") -Destination (Join-Path $script:repoPath ".git/hooks/post-commit") -Force
        Copy-Item -Path (Join-Path $script:repoRoot "hooks" "post-merge") -Destination (Join-Path $script:repoPath ".git/hooks/post-merge") -Force
        Get-ChildItem -Path (Join-Path $script:repoPath ".git/hooks") -Filter "post-*" | ForEach-Object { $_.LastWriteTime = Get-Date; chmod +x $_.FullName }

        git add .
        git commit -m "chore: seed integration repo" | Out-Null
        Pop-Location

        $env:PSModulePath = "$($script:deployBase){0}$($env:PSModulePath)" -f [IO.Path]::PathSeparator
    }

    AfterAll {
        if (Get-Module -Name $script:moduleName -ErrorAction SilentlyContinue) {
            Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path -LiteralPath $script:testRoot) {
            Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "Deploys modules after commit" {
        Push-Location $script:repoPath
        Add-Content -Path $script:moduleRelPath -Value "# commit deployment" -Encoding utf8
        git add $script:moduleRelPath
        git commit -m "test: trigger post-commit" | Out-Null
        Pop-Location

        $stagedFile = Join-Path $script:stagingMirror $script:moduleRelPath
        $deployedModule = Join-Path $script:deployBase "$($script:moduleName)/$($script:moduleVersion)/$($script:moduleName).psm1"
        $deployedManifest = Join-Path $script:deployBase "$($script:moduleName)/$($script:moduleVersion)/$($script:moduleName).psd1"

        Test-Path -LiteralPath $stagedFile | Should -BeTrue
        Test-Path -LiteralPath $deployedModule | Should -BeTrue
        Test-Path -LiteralPath $deployedManifest | Should -BeTrue

        Import-Module -Name $deployedModule -Force
        (Get-IntegrationSample) | Should -Be "integration works"
    }

    It "Post-merge hook deploys merged module updates" {
        Push-Location $script:repoPath
        git checkout -b feature/update-module | Out-Null

        (Get-Content -Path $script:moduleRelPath -Raw).Replace($script:moduleVersion, "1.2.4") | Set-Content -Path $script:moduleRelPath -Encoding utf8
        git add $script:moduleRelPath
        git commit -m "feat: bump integration module" | Out-Null

        git checkout main | Out-Null
        git merge feature/update-module -m "merge feature branch" | Out-Null
        Pop-Location

        $mergedModule = Join-Path $script:deployBase "$($script:moduleName)/1.2.4/$($script:moduleName).psm1"
        $mergedManifest = Join-Path $script:deployBase "$($script:moduleName)/1.2.4/$($script:moduleName).psd1"

        Test-Path -LiteralPath $mergedModule | Should -BeTrue
        Test-Path -LiteralPath $mergedManifest | Should -BeTrue
    }

    It "Respects local deployment configuration settings" {
        $newMirror = Join-Path $script:testRoot "staging-new"
        New-Item -Path $newMirror -ItemType Directory -Force | Out-Null

        $script:stagingMirror = $newMirror
        $localConfig = @{ stagingMirror = $script:stagingMirror; enabled = $true } | ConvertTo-Json
        $localConfig | Set-Content -Path (Join-Path $script:repoPath "config" "local-deployment-config.json") -Encoding utf8

        Push-Location $script:repoPath
        Remove-Item -LiteralPath (Join-Path $script:testRoot "staging") -Recurse -Force -ErrorAction SilentlyContinue
        Add-Content -Path $script:moduleRelPath -Value "# updated mirror" -Encoding utf8
        git add $script:moduleRelPath
        git commit -m "test: move staging mirror" | Out-Null
        Pop-Location

        $stagedFile = Join-Path $script:stagingMirror $script:moduleRelPath
        Test-Path -LiteralPath $stagedFile | Should -BeTrue
    }
}
