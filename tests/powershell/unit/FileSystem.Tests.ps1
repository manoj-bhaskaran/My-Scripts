# FileSystem Module Tests
BeforeAll {
    $modulePath = "$PSScriptRoot/../../../src/powershell/modules/Core/FileSystem"
    Import-Module $modulePath -Force
}

Describe "FileSystem Module" {
    Context "New-DirectoryIfMissing" {
        It "Creates new directory" {
            $path = "TestDrive:/NewDir"
            $result = New-DirectoryIfMissing -Path $path
            Test-Path $path | Should -Be $true
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames | Should -Contain 'System.IO.DirectoryInfo'
        }

        It "Returns existing directory without error" {
            $path = "TestDrive:/Existing"
            New-Item -ItemType Directory -Path $path
            { New-DirectoryIfMissing -Path $path } | Should -Not -Throw
            Test-Path $path | Should -Be $true
        }

        It "Creates nested directories with Force" {
            $path = "TestDrive:/Parent/Child/GrandChild"
            $result = New-DirectoryIfMissing -Path $path -Force
            Test-Path $path | Should -Be $true
            $result | Should -Not -BeNullOrEmpty
        }

        It "Throws error for invalid path without Force" {
            $path = "TestDrive:/Parent2/Child2/GrandChild2"
            { New-DirectoryIfMissing -Path $path } | Should -Throw
        }
    }

    Context "Test-FileAccessible" {
        It "Returns true for accessible file" {
            $file = "TestDrive:/test.txt"
            "content" | Out-File $file
            Test-FileAccessible -Path $file | Should -Be $true
        }

        It "Returns false for non-existent file" {
            Test-FileAccessible -Path "TestDrive:/missing.txt" | Should -Be $false
        }

        It "Tests write access" {
            $file = "TestDrive:/writable.txt"
            "content" | Out-File $file
            Test-FileAccessible -Path $file -Access Write | Should -Be $true
        }

        It "Tests read-write access" {
            $file = "TestDrive:/readwrite.txt"
            "content" | Out-File $file
            Test-FileAccessible -Path $file -Access ReadWrite | Should -Be $true
        }

        It "Returns false for directory" {
            $dir = "TestDrive:/TestDir"
            New-Item -ItemType Directory -Path $dir
            Test-FileAccessible -Path $dir | Should -Be $false
        }
    }

    Context "Test-PathValid" {
        It "Returns true for valid path" {
            Test-PathValid -Path "C:\temp\file.txt" | Should -Be $true
        }

        It "Returns false for path with invalid characters" {
            Test-PathValid -Path "C:\temp\<invalid>.txt" | Should -Be $false
        }

        It "Returns false for empty path" {
            Test-PathValid -Path "" | Should -Be $false
        }

        It "Returns false for whitespace-only path" {
            Test-PathValid -Path "   " | Should -Be $false
        }

        It "Returns true for wildcards when allowed" {
            Test-PathValid -Path "C:\temp\*.txt" -AllowWildcards | Should -Be $true
        }

        It "Returns false for wildcards when not allowed" {
            Test-PathValid -Path "C:\temp\*.txt" | Should -Be $false
        }

        It "Returns true for relative path" {
            Test-PathValid -Path ".\relative\path.txt" | Should -Be $true
        }

        It "Returns false for path with pipe character" {
            Test-PathValid -Path "C:\temp\file|name.txt" | Should -Be $false
        }
    }

    Context "Test-FileLocked" {
        It "Detects unlocked file" {
            $file = "TestDrive:/unlocked.txt"
            "content" | Out-File $file
            Test-FileLocked -Path $file | Should -Be $false
        }

        It "Returns false for non-existent file" {
            Test-FileLocked -Path "TestDrive:/missing.txt" | Should -Be $false
        }

        It "Detects locked file" {
            $file = "TestDrive:/locked.txt"
            "content" | Out-File $file

            # Resolve the path for .NET file operations
            $resolvedPath = (Get-Item -Path $file).FullName

            # Open the file with exclusive access to lock it
            $stream = [System.IO.File]::Open($resolvedPath, 'Open', 'ReadWrite', 'None')

            try {
                Test-FileLocked -Path $file | Should -Be $true
            } finally {
                $stream.Close()
            }
        }

        It "Returns false after file is unlocked" {
            $file = "TestDrive:/temp-lock.txt"
            "content" | Out-File $file

            # Resolve the path for .NET file operations
            $resolvedPath = (Get-Item -Path $file).FullName

            $stream = [System.IO.File]::Open($resolvedPath, 'Open', 'ReadWrite', 'None')
            $stream.Close()

            Test-FileLocked -Path $file | Should -Be $false
        }
    }

    Context "Module Exports" {
        It "Exports expected functions" {
            $commands = Get-Command -Module FileSystem
            $commands.Name | Should -Contain 'New-DirectoryIfMissing'
            $commands.Name | Should -Contain 'Test-FileAccessible'
            $commands.Name | Should -Contain 'Test-PathValid'
            $commands.Name | Should -Contain 'Test-FileLocked'
        }

        It "Does not export private functions" {
            $commands = Get-Command -Module FileSystem
            $commands.Name | Should -Not -Contain 'Get-FileLockInfo'
        }
    }
}
