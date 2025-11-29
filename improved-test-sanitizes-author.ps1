# Improved version of the "Sanitizes author and description fields" test
# This addresses potential race conditions and provides better debugging

It "Sanitizes author and description fields" {
    # Test with potentially unsafe author/description using control character
    $unsafeAuthor = "Author$([char]1)WithControlChar"  # Contains control character
    $configContent = "TestModule|TestModule.psm1|User|$unsafeAuthor"
    $configContent | Out-File -FilePath $script:testConfigPath -Force

    # Ensure the config file is written and module file exists
    Start-Sleep -Milliseconds 50  # Brief pause to ensure file operations complete

    # Verify test setup
    $configExists = Test-Path -Path $script:testConfigPath
    $moduleExists = Test-Path -Path (Join-Path $script:testRepoPath "TestModule.psm1")

    if (-not $configExists) {
        throw "Config file was not created: $script:testConfigPath"
    }
    if (-not $moduleExists) {
        throw "Module file was not created: $(Join-Path $script:testRepoPath "TestModule.psm1")"
    }

    # Set up mocks with additional verification
    Mock Write-Message {
        Write-Host "Mock Write-Message called with: $args" -ForegroundColor Yellow
    }
    Mock New-DirectoryIfMissing {
        Write-Host "Mock New-DirectoryIfMissing called with: $args" -ForegroundColor Yellow
        return $true
    }
    Mock Copy-Item {
        Write-Host "Mock Copy-Item called with: $args" -ForegroundColor Yellow
        return $true
    }
    Mock New-OrUpdateManifest {
        Write-Host "Mock New-OrUpdateManifest called with Author: $Author, Description: $Description" -ForegroundColor Green
        return $true
    }

    # Also mock Test-ModuleSanity to ensure it passes
    Mock Test-ModuleSanity {
        Write-Host "Mock Test-ModuleSanity called with: $args" -ForegroundColor Yellow
        return $true
    }

    # Execute the function
    Deploy-ModuleFromConfig `
        -RepoPath $script:testRepoPath `
        -ConfigPath $script:testConfigPath

    # Verify the expected behavior: should use default author due to sanitization
    Assert-MockCalled New-OrUpdateManifest -Times 1 -ParameterFilter {
        $Author -eq $env:USERNAME -and $Description -eq "PowerShell module"
    }

    # Additional verification that other functions were called
    Assert-MockCalled Copy-Item -Times 1
    Assert-MockCalled New-DirectoryIfMissing -Times 1
}
