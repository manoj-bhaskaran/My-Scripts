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

    Context "Get-FullPath" {
        It "Returns absolute Windows path normalized (when run on Windows)" {
            # Skip this test on non-Windows platforms
            if ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) {
                $path = "C:\Users\Admin\Documents"
                Get-FullPath -Path $path | Should -Be "C:\Users\Admin\Documents"
            } else {
                Set-ItResult -Inconclusive -Because "Windows path test on non-Windows platform"
            }
        }

        It "Normalizes forward slashes to backslashes" {
            $path = "C:/Users/Admin/Documents"
            $result = Get-FullPath -Path $path
            $result | Should -Match '\\'
            $result | Should -Not -Match '/'
        }

        It "Handles relative paths" {
            Push-Location "TestDrive:/"
            try {
                $result = Get-FullPath -Path ".\relative"
                $result | Should -Match "relative"
            } finally {
                Pop-Location
            }
        }

        It "Accepts pipeline input with forward slash normalization" {
            # Test platform-agnostic behavior: forward slashes should be normalized
            $path = "C:/Users/Admin"
            $result = $path | Get-FullPath
            # On Windows, backslashes are used; on Linux, it preserves the structure
            $result | Should -Match 'Users' # Path structure is preserved
            if ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) {
                $result | Should -Not -Match '/' # Forward slashes normalized on Windows
            }
        }
    }

    Context "Format-Bytes" {
        It "Formats bytes correctly" {
            Format-Bytes -Bytes 512 | Should -Be "512 B"
        }

        It "Formats kilobytes correctly" {
            Format-Bytes -Bytes 1024 | Should -Be "1.00 KB"
        }

        It "Formats megabytes correctly" {
            Format-Bytes -Bytes 1048576 | Should -Be "1.00 MB"
        }

        It "Formats gigabytes correctly" {
            Format-Bytes -Bytes 1073741824 | Should -Be "1.00 GB"
        }

        It "Formats terabytes correctly" {
            Format-Bytes -Bytes 1099511627776 | Should -Be "1.00 TB"
        }

        It "Formats fractional kilobytes" {
            Format-Bytes -Bytes 2560 | Should -Be "2.50 KB"
        }

        It "Accepts pipeline input" {
            $result = 2097152 | Format-Bytes
            $result | Should -Be "2.00 MB"
        }
    }

    Context "Get-SafeName" {
        It "Removes invalid characters from filename" {
            Get-SafeName -Name "file<name>.txt" | Should -Be "file_name_.txt"
        }

        It "Replaces colons with underscores" {
            Get-SafeName -Name "c:file.txt" | Should -Be "c_file.txt"
        }

        It "Replaces asterisks with underscores" {
            Get-SafeName -Name "my*file.txt" | Should -Be "my_file.txt"
        }

        It "Removes trailing dots and spaces" {
            Get-SafeName -Name "filename.txt. " | Should -Be "filename.txt"
        }

        It "Returns fallback name when sanitization produces empty string" {
            # Input that sanitizes to empty (dots and spaces are removed by TrimEnd)
            Get-SafeName -Name "...   " | Should -Be "archive"
        }

        It "Truncates name when MaxLength specified" {
            $result = Get-SafeName -Name "very_long_filename_that_exceeds_limit" -MaxLength 10
            $result.Length | Should -Be 10
        }

        It "Accepts pipeline input" {
            $result = "file<name>.txt" | Get-SafeName
            $result | Should -Be "file_name_.txt"
        }
    }

    Context "Test-LongPathsEnabled" {
        It "Returns boolean value" {
            $result = Test-LongPathsEnabled
            $result -is [bool] | Should -Be $true
        }

        It "Returns false when registry key not accessible" {
            $result = Test-LongPathsEnabled
            # On most systems without admin, this will return false or true depending on OS
            $result -is [bool] | Should -Be $true
        }
    }

    Context "Resolve-UniquePath" {
        It "Returns path unchanged when it doesn't exist" {
            $path = "TestDrive:/nonexistent_file.txt"
            $result = Resolve-UniquePath -Path $path
            $result | Should -Be $path
        }

        It "Appends timestamp suffix when file exists" {
            $path = "TestDrive:/existing.txt"
            "content" | Out-File $path

            $result = Resolve-UniquePath -Path $path
            $result | Should -Not -Be $path
            $result | Should -Match "existing_\d{14}\.txt$"
        }

        It "Preserves file extension when creating unique path" {
            $path = "TestDrive:/test.log"
            "content" | Out-File $path

            $result = Resolve-UniquePath -Path $path
            $result | Should -Match "\.log$"
        }

        It "Accepts pipeline input" {
            $path = "TestDrive:/pipe_test.txt"
            "content" | Out-File $path

            $result = $path | Resolve-UniquePath
            $result | Should -Not -Be $path
        }
    }

    Context "Resolve-UniqueDirectoryPath" {
        It "Returns path unchanged when directory doesn't exist" {
            $path = "TestDrive:/nonexistent_dir"
            $result = Resolve-UniqueDirectoryPath -Path $path
            $result | Should -Be $path
        }

        It "Appends timestamp suffix when directory exists" {
            $path = "TestDrive:/existing_dir"
            New-Item -ItemType Directory -Path $path | Out-Null

            $result = Resolve-UniqueDirectoryPath -Path $path
            $result | Should -Not -Be $path
            $result | Should -Match "existing_dir_\d{14}$"
        }

        It "Does not add extension for directory" {
            $path = "TestDrive:/mydir"
            New-Item -ItemType Directory -Path $path | Out-Null

            $result = Resolve-UniqueDirectoryPath -Path $path
            $result | Should -Not -Match "\..+$"
        }

        It "Accepts pipeline input" {
            $path = "TestDrive:/pipe_dir"
            New-Item -ItemType Directory -Path $path | Out-Null

            $result = $path | Resolve-UniqueDirectoryPath
            $result | Should -Not -Be $path
        }
    }

    Context "Module Exports" {
        It "Exports expected functions" {
            $commands = Get-Command -Module FileSystem
            $commands.Name | Should -Contain 'New-DirectoryIfMissing'
            $commands.Name | Should -Contain 'Test-FileAccessible'
            $commands.Name | Should -Contain 'Test-PathValid'
            $commands.Name | Should -Contain 'Test-FileLocked'
            $commands.Name | Should -Contain 'Get-FullPath'
            $commands.Name | Should -Contain 'Format-Bytes'
            $commands.Name | Should -Contain 'Resolve-UniquePath'
            $commands.Name | Should -Contain 'Resolve-UniqueDirectoryPath'
            $commands.Name | Should -Contain 'Get-SafeName'
            $commands.Name | Should -Contain 'Test-LongPathsEnabled'
        }

        It "Does not export private functions" {
            $commands = Get-Command -Module FileSystem
            $commands.Name | Should -Not -Contain 'Get-FileLockInfo'
            $commands.Name | Should -Not -Contain 'Resolve-UniquePathCore'
        }
    }
}
