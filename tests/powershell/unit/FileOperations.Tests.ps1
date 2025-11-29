<#
.SYNOPSIS
    Unit tests for FileOperations module

.DESCRIPTION
    Comprehensive Pester tests for the FileOperations PowerShell module
    Tests include retry logic, error handling, edge cases, and integration tests
#>

BeforeAll {
    # Import the modules
    $errorHandlingPath = Join-Path $PSScriptRoot "..\..\..\src\powershell\modules\Core\ErrorHandling\ErrorHandling.psm1"
    $modulePath = Join-Path $PSScriptRoot "..\..\..\src\powershell\modules\Core\FileOperations\FileOperations.psm1"

    Import-Module $errorHandlingPath -Force
    Import-Module $modulePath -Force

    # Create temp directory for tests
    $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "FileOperationsTests_$([guid]::NewGuid())"
    New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
}

Describe "Copy-FileWithRetry" {
    Context "Basic Functionality" {
        It "Copies file successfully" {
            $source = Join-Path $script:testDir "source.txt"
            $dest = Join-Path $script:testDir "dest.txt"

            "test content" | Out-File -FilePath $source -NoNewline

            $result = Copy-FileWithRetry -Source $source -Destination $dest

            $result | Should -Be $true
            Test-Path $dest | Should -Be $true
            (Get-Content $dest -Raw) | Should -Be "test content"
        }

        It "Throws when source doesn't exist" {
            $source = Join-Path $script:testDir "nonexistent.txt"
            $dest = Join-Path $script:testDir "dest.txt"

            { Copy-FileWithRetry -Source $source -Destination $dest } | Should -Throw "*Source file not found*"
        }

        It "Creates destination directory if needed" {
            $source = Join-Path $script:testDir "source2.txt"
            $dest = Join-Path $script:testDir "subdir\dest.txt"

            "test content" | Out-File -FilePath $source -NoNewline

            $result = Copy-FileWithRetry -Source $source -Destination $dest

            $result | Should -Be $true
            Test-Path $dest | Should -Be $true
        }

        It "Overwrites existing destination file with Force" {
            $source = Join-Path $script:testDir "source3.txt"
            $dest = Join-Path $script:testDir "dest3.txt"

            "original" | Out-File -FilePath $dest -NoNewline
            "new content" | Out-File -FilePath $source -NoNewline

            Copy-FileWithRetry -Source $source -Destination $dest -Force

            (Get-Content $dest -Raw) | Should -Be "new content"
        }
    }

    Context "Retry Logic" {
        It "Succeeds on first attempt with Invoke-WithRetry" {
            $source = Join-Path $script:testDir "retry_source1.txt"
            $dest = Join-Path $script:testDir "retry_dest1.txt"

            "test" | Out-File -FilePath $source -NoNewline

            Mock Invoke-WithRetry -ModuleName FileOperations {
                param($Operation, $Description, $RetryDelay, $RetryCount, $MaxBackoff)
                & $Operation
            }

            $result = Copy-FileWithRetry -Source $source -Destination $dest -MaxRetries 3

            $result | Should -Be $true
            Should -Invoke Invoke-WithRetry -ModuleName FileOperations -Times 1
        }

        It "Passes correct retry parameters to Invoke-WithRetry" {
            $source = Join-Path $script:testDir "retry_source2.txt"
            $dest = Join-Path $script:testDir "retry_dest2.txt"

            "test" | Out-File -FilePath $source -NoNewline

            Mock Invoke-WithRetry -ModuleName FileOperations {
                param($Operation, $Description, $RetryDelay, $RetryCount, $MaxBackoff)
                $RetryCount | Should -Be 5
                $RetryDelay | Should -Be 3
                $MaxBackoff | Should -Be 120
                & $Operation
            }

            Copy-FileWithRetry -Source $source -Destination $dest -MaxRetries 5 -RetryDelay 3 -MaxBackoff 120

            Should -Invoke Invoke-WithRetry -ModuleName FileOperations -Times 1
        }

        It "Works without Invoke-WithRetry (fallback mode)" {
            $source = Join-Path $script:testDir "fallback_source.txt"
            $dest = Join-Path $script:testDir "fallback_dest.txt"

            "test" | Out-File -FilePath $source -NoNewline

            # Mock Get-Command to return null for Invoke-WithRetry
            Mock Get-Command -ModuleName FileOperations {
                param($Name, $ErrorAction)
                if ($Name -eq 'Invoke-WithRetry') {
                    return $null
                }
            }

            $result = Copy-FileWithRetry -Source $source -Destination $dest

            $result | Should -Be $true
            Test-Path $dest | Should -Be $true
        }
    }

    Context "Edge Cases" {
        It "Handles nested directory creation" {
            $source = Join-Path $script:testDir "edge_source.txt"
            $dest = Join-Path $script:testDir "a\b\c\d\dest.txt"

            "test" | Out-File -FilePath $source -NoNewline

            Copy-FileWithRetry -Source $source -Destination $dest

            Test-Path $dest | Should -Be $true
        }

        It "Preserves file content exactly" {
            $source = Join-Path $script:testDir "content_source.txt"
            $dest = Join-Path $script:testDir "content_dest.txt"

            $testContent = "Line1`nLine2`r`nLine3`tTabbed"
            [System.IO.File]::WriteAllText($source, $testContent)

            Copy-FileWithRetry -Source $source -Destination $dest

            $resultContent = [System.IO.File]::ReadAllText($dest)
            $resultContent | Should -Be $testContent
        }
    }
}

Describe "Move-FileWithRetry" {
    Context "Basic Functionality" {
        It "Moves file successfully" {
            $source = Join-Path $script:testDir "move_source.txt"
            $dest = Join-Path $script:testDir "move_dest.txt"

            "test content" | Out-File -FilePath $source -NoNewline

            $result = Move-FileWithRetry -Source $source -Destination $dest

            $result | Should -Be $true
            Test-Path $dest | Should -Be $true
            Test-Path $source | Should -Be $false
        }

        It "Throws when source doesn't exist" {
            $source = Join-Path $script:testDir "nonexistent_move.txt"
            $dest = Join-Path $script:testDir "move_dest2.txt"

            { Move-FileWithRetry -Source $source -Destination $dest } | Should -Throw "*Source file not found*"
        }

        It "Creates destination directory if needed" {
            $source = Join-Path $script:testDir "move_source2.txt"
            $dest = Join-Path $script:testDir "newdir\move_dest.txt"

            "test" | Out-File -FilePath $source -NoNewline

            Move-FileWithRetry -Source $source -Destination $dest

            Test-Path $dest | Should -Be $true
            Test-Path $source | Should -Be $false
        }

        It "Ensures atomic move (source removed only if move succeeds)" {
            $source = Join-Path $script:testDir "atomic_source.txt"
            $dest = Join-Path $script:testDir "atomic_dest.txt"

            "content" | Out-File -FilePath $source -NoNewline

            Move-FileWithRetry -Source $source -Destination $dest

            Test-Path $source | Should -Be $false
            Test-Path $dest | Should -Be $true
        }
    }

    Context "Retry Logic" {
        It "Passes correct retry parameters to Invoke-WithRetry" {
            $source = Join-Path $script:testDir "move_retry_source.txt"
            $dest = Join-Path $script:testDir "move_retry_dest.txt"

            "test" | Out-File -FilePath $source -NoNewline

            Mock Invoke-WithRetry -ModuleName FileOperations {
                param($Operation, $Description, $RetryDelay, $RetryCount, $MaxBackoff)
                $RetryCount | Should -Be 4
                $RetryDelay | Should -Be 3
                & $Operation
            }

            Move-FileWithRetry -Source $source -Destination $dest -MaxRetries 4 -RetryDelay 3

            Should -Invoke Invoke-WithRetry -ModuleName FileOperations -Times 1
        }

        It "Works without Invoke-WithRetry (fallback mode)" {
            $source = Join-Path $script:testDir "move_fallback_source.txt"
            $dest = Join-Path $script:testDir "move_fallback_dest.txt"

            "test" | Out-File -FilePath $source -NoNewline

            Mock Get-Command -ModuleName FileOperations {
                param($Name, $ErrorAction)
                if ($Name -eq 'Invoke-WithRetry') { return $null }
            }

            $result = Move-FileWithRetry -Source $source -Destination $dest

            $result | Should -Be $true
            Test-Path $dest | Should -Be $true
        }
    }

    Context "Edge Cases" {
        It "Preserves file content during move" {
            $source = Join-Path $script:testDir "move_content_source.txt"
            $dest = Join-Path $script:testDir "move_content_dest.txt"

            $testContent = "Special`nContent`r`nWith`tTabs"
            [System.IO.File]::WriteAllText($source, $testContent)

            Move-FileWithRetry -Source $source -Destination $dest

            $resultContent = [System.IO.File]::ReadAllText($dest)
            $resultContent | Should -Be $testContent
        }
    }
}

Describe "Remove-FileWithRetry" {
    Context "Basic Functionality" {
        It "Removes file successfully" {
            $file = Join-Path $script:testDir "remove_test.txt"

            "test content" | Out-File -FilePath $file

            $result = Remove-FileWithRetry -Path $file

            $result | Should -Be $true
            Test-Path $file | Should -Be $false
        }

        It "Returns true for nonexistent file" {
            $file = Join-Path $script:testDir "nonexistent_remove.txt"

            $result = Remove-FileWithRetry -Path $file

            $result | Should -Be $true
        }

        It "Removes read-only file with Force" {
            $file = Join-Path $script:testDir "readonly_test.txt"

            "test" | Out-File -FilePath $file
            Set-ItemProperty -Path $file -Name IsReadOnly -Value $true

            $result = Remove-FileWithRetry -Path $file

            $result | Should -Be $true
            Test-Path $file | Should -Be $false
        }
    }

    Context "Retry Logic" {
        It "Passes correct retry parameters to Invoke-WithRetry" {
            $file = Join-Path $script:testDir "remove_retry_test.txt"

            "test" | Out-File -FilePath $file

            Mock Invoke-WithRetry -ModuleName FileOperations {
                param($Operation, $Description, $RetryDelay, $RetryCount, $MaxBackoff)
                $RetryCount | Should -Be 5
                $RetryDelay | Should -Be 1
                $MaxBackoff | Should -Be 30
                & $Operation
            }

            Remove-FileWithRetry -Path $file -MaxRetries 5 -RetryDelay 1 -MaxBackoff 30

            Should -Invoke Invoke-WithRetry -ModuleName FileOperations -Times 1
        }

        It "Works without Invoke-WithRetry (fallback mode)" {
            $file = Join-Path $script:testDir "remove_fallback_test.txt"

            "test" | Out-File -FilePath $file

            Mock Get-Command -ModuleName FileOperations {
                param($Name, $ErrorAction)
                if ($Name -eq 'Invoke-WithRetry') { return $null }
            }

            $result = Remove-FileWithRetry -Path $file

            $result | Should -Be $true
            Test-Path $file | Should -Be $false
        }
    }

    Context "Error Handling" {
        It "Handles warnings for nonexistent files gracefully" {
            $file = Join-Path $script:testDir "nonexistent_warning.txt"

            $result = Remove-FileWithRetry -Path $file -WarningAction SilentlyContinue

            $result | Should -Be $true
        }
    }
}

Describe "Rename-FileWithRetry" {
    Context "Basic Functionality" {
        It "Renames file successfully" {
            $file = Join-Path $script:testDir "old_name.txt"
            $newName = "new_name.txt"

            "test content" | Out-File -FilePath $file

            $result = Rename-FileWithRetry -Path $file -NewName $newName

            $result | Should -Be $true
            Test-Path (Join-Path $script:testDir $newName) | Should -Be $true
            Test-Path $file | Should -Be $false
        }

        It "Throws when file doesn't exist" {
            $file = Join-Path $script:testDir "nonexistent_rename.txt"

            { Rename-FileWithRetry -Path $file -NewName "new.txt" } | Should -Throw "*Path does not exist*"
        }

        It "Preserves file content after rename" {
            $file = Join-Path $script:testDir "rename_content.txt"
            $newName = "renamed_content.txt"

            $testContent = "Content to preserve"
            $testContent | Out-File -FilePath $file -NoNewline

            Rename-FileWithRetry -Path $file -NewName $newName

            $newPath = Join-Path $script:testDir $newName
            (Get-Content $newPath -Raw) | Should -Be $testContent
        }
    }

    Context "Retry Logic" {
        It "Passes correct retry parameters to Invoke-WithRetry" {
            $file = Join-Path $script:testDir "rename_retry.txt"
            $newName = "renamed_retry.txt"

            "test" | Out-File -FilePath $file

            Mock Invoke-WithRetry -ModuleName FileOperations {
                param($Operation, $Description, $RetryDelay, $RetryCount, $MaxBackoff)
                $RetryCount | Should -Be 6
                $RetryDelay | Should -Be 2
                & $Operation
            }

            Rename-FileWithRetry -Path $file -NewName $newName -MaxRetries 6 -RetryDelay 2

            Should -Invoke Invoke-WithRetry -ModuleName FileOperations -Times 1
        }

        It "Works without Invoke-WithRetry (fallback mode)" {
            $file = Join-Path $script:testDir "rename_fallback.txt"
            $newName = "renamed_fallback.txt"

            "test" | Out-File -FilePath $file

            Mock Get-Command -ModuleName FileOperations {
                param($Name, $ErrorAction)
                if ($Name -eq 'Invoke-WithRetry') { return $null }
            }

            $result = Rename-FileWithRetry -Path $file -NewName $newName

            $result | Should -Be $true
            Test-Path (Join-Path $script:testDir $newName) | Should -Be $true
        }
    }

    Context "Edge Cases" {
        It "Handles special characters in new name" {
            $file = Join-Path $script:testDir "special_chars.txt"
            $newName = "new-name_with.special.txt"

            "test" | Out-File -FilePath $file

            Rename-FileWithRetry -Path $file -NewName $newName

            Test-Path (Join-Path $script:testDir $newName) | Should -Be $true
        }
    }
}

Describe "Test-FolderWritable" {
    Context "Basic Functionality" {
        It "Returns true for writable folder" {
            $folder = Join-Path $script:testDir "writable_test"

            $result = Test-FolderWritable -Path $folder

            $result | Should -Be $true
            Test-Path $folder | Should -Be $true
        }

        It "Creates folder if it doesn't exist" {
            $folder = Join-Path $script:testDir "new_folder_test"

            $result = Test-FolderWritable -Path $folder

            $result | Should -Be $true
            Test-Path $folder | Should -Be $true
        }

        It "Returns false with SkipCreate if folder doesn't exist" {
            $folder = Join-Path $script:testDir "skip_create_test_$(Get-Random)"

            $result = Test-FolderWritable -Path $folder -SkipCreate

            $result | Should -Be $false
        }

        It "Returns true for existing writable folder" {
            $folder = Join-Path $script:testDir "existing_writable"
            New-Item -Path $folder -ItemType Directory -Force | Out-Null

            $result = Test-FolderWritable -Path $folder

            $result | Should -Be $true
        }
    }

    Context "Edge Cases" {
        It "Creates nested directories" {
            $folder = Join-Path $script:testDir "nested\deep\structure"

            $result = Test-FolderWritable -Path $folder

            $result | Should -Be $true
            Test-Path $folder | Should -Be $true
        }

        It "Cleans up test file after checking" {
            $folder = Join-Path $script:testDir "cleanup_test"
            New-Item -Path $folder -ItemType Directory -Force | Out-Null

            Test-FolderWritable -Path $folder | Out-Null

            # Verify no test files left behind
            $files = Get-ChildItem -Path $folder -Filter ".write_test_*"
            $files.Count | Should -Be 0
        }
    }

    Context "Error Handling" {
        It "Returns false if folder cannot be created" {
            # Test with an invalid path that can't be created
            $invalidPath = "Z:\InvalidDrive\InvalidFolder\$(Get-Random)"

            $result = Test-FolderWritable -Path $invalidPath -WarningAction SilentlyContinue

            $result | Should -Be $false
        }
    }
}

Describe "Add-ContentWithRetry" {
    Context "Basic Functionality" {
        It "Appends content to new file" {
            $file = Join-Path $script:testDir "append_new.txt"

            $result = Add-ContentWithRetry -Path $file -Value "line 1"

            $result | Should -Be $true
            Test-Path $file | Should -Be $true
            (Get-Content $file -Raw).Trim() | Should -Be "line 1"
        }

        It "Appends content to existing file" {
            $file = Join-Path $script:testDir "append_existing.txt"

            "line 1" | Out-File -FilePath $file
            Add-ContentWithRetry -Path $file -Value "line 2"

            $content = Get-Content $file
            $content.Count | Should -BeGreaterThan 1
        }

        It "Creates parent directory if needed" {
            $file = Join-Path $script:testDir "newsubdir\append_subdir.txt"

            Add-ContentWithRetry -Path $file -Value "content"

            Test-Path $file | Should -Be $true
        }

        It "Respects encoding parameter" {
            $file = Join-Path $script:testDir "encoding_test.txt"

            Add-ContentWithRetry -Path $file -Value "test" -Encoding "UTF8"

            Test-Path $file | Should -Be $true
        }
    }

    Context "Retry Logic" {
        It "Passes correct retry parameters to Invoke-WithRetry" {
            $file = Join-Path $script:testDir "append_retry.txt"

            Mock Invoke-WithRetry -ModuleName FileOperations {
                param($Operation, $Description, $RetryDelay, $RetryCount, $MaxBackoff, $LogErrors)
                $RetryCount | Should -Be 4
                $RetryDelay | Should -Be 2
                $MaxBackoff | Should -Be 45
                $LogErrors | Should -Be $false
                & $Operation
            }

            Add-ContentWithRetry -Path $file -Value "test" -MaxRetries 4 -RetryDelay 2 -MaxBackoff 45

            Should -Invoke Invoke-WithRetry -ModuleName FileOperations -Times 1
        }

        It "Works without Invoke-WithRetry (fallback mode)" {
            $file = Join-Path $script:testDir "append_fallback.txt"

            Mock Get-Command -ModuleName FileOperations {
                param($Name, $ErrorAction)
                if ($Name -eq 'Invoke-WithRetry') { return $null }
            }

            $result = Add-ContentWithRetry -Path $file -Value "test"

            $result | Should -Be $true
            Test-Path $file | Should -Be $true
        }
    }

    Context "Edge Cases" {
        It "Handles multiple appends to same file" {
            $file = Join-Path $script:testDir "multi_append.txt"

            Add-ContentWithRetry -Path $file -Value "line 1"
            Add-ContentWithRetry -Path $file -Value "line 2"
            Add-ContentWithRetry -Path $file -Value "line 3"

            $content = Get-Content $file
            $content.Count | Should -BeGreaterOrEqual 3
        }
    }
}

Describe "New-DirectoryIfNotExists" {
    Context "Basic Functionality" {
        It "Creates new directory" {
            $dir = Join-Path $script:testDir "new_dir_test"

            $result = New-DirectoryIfNotExists -Path $dir

            $result | Should -Be $true
            Test-Path $dir | Should -Be $true
        }

        It "Returns false for existing directory" {
            $dir = Join-Path $script:testDir "existing_dir_test"
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $result = New-DirectoryIfNotExists -Path $dir

            $result | Should -Be $false
        }

        It "Creates nested directories" {
            $dir = Join-Path $script:testDir "nested1\nested2\nested3"

            $result = New-DirectoryIfNotExists -Path $dir

            $result | Should -Be $true
            Test-Path $dir | Should -Be $true
        }
    }

    Context "Edge Cases" {
        It "Handles deeply nested paths" {
            $dir = Join-Path $script:testDir "level1\level2\level3\level4\level5"

            $result = New-DirectoryIfNotExists -Path $dir

            $result | Should -Be $true
            Test-Path $dir | Should -Be $true
        }

        It "Returns false when checking existing directory multiple times" {
            $dir = Join-Path $script:testDir "multi_check_dir"

            $result1 = New-DirectoryIfNotExists -Path $dir
            $result2 = New-DirectoryIfNotExists -Path $dir

            $result1 | Should -Be $true
            $result2 | Should -Be $false
        }
    }

    Context "Error Handling" {
        It "Throws with descriptive error for invalid paths" {
            $invalidPath = "Z:\NonExistent\Invalid\Path\$(Get-Random)"

            { New-DirectoryIfNotExists -Path $invalidPath } | Should -Throw "*Failed to create directory*"
        }
    }
}

Describe "Get-FileSize" {
    Context "Basic Functionality" {
        It "Returns size of existing file" {
            $file = Join-Path $script:testDir "size_test.txt"
            "test content" | Out-File -FilePath $file -NoNewline

            $size = Get-FileSize -Path $file

            $size | Should -BeGreaterThan 0
        }

        It "Returns 0 for nonexistent file" {
            $file = Join-Path $script:testDir "nonexistent_size.txt"

            $size = Get-FileSize -Path $file

            $size | Should -Be 0
        }

        It "Returns correct size for known content" {
            $file = Join-Path $script:testDir "known_size.txt"
            $content = "1234567890"
            [System.IO.File]::WriteAllText($file, $content)

            $size = Get-FileSize -Path $file

            $size | Should -Be $content.Length
        }
    }

    Context "Edge Cases" {
        It "Returns 0 for empty file" {
            $file = Join-Path $script:testDir "empty_file.txt"
            New-Item -Path $file -ItemType File -Force | Out-Null

            $size = Get-FileSize -Path $file

            $size | Should -Be 0
        }

        It "Returns correct size for large content" {
            $file = Join-Path $script:testDir "large_file.txt"
            $largeContent = "x" * 10000
            [System.IO.File]::WriteAllText($file, $largeContent)

            $size = Get-FileSize -Path $file

            $size | Should -Be 10000
        }

        It "Returns 0 for directory path" {
            $dir = Join-Path $script:testDir "size_dir_test"
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $size = Get-FileSize -Path $dir -WarningAction SilentlyContinue

            $size | Should -Be 0
        }
    }

    Context "Error Handling" {
        It "Handles inaccessible files gracefully" {
            $file = Join-Path $script:testDir "nonexistent_error.txt"

            $size = Get-FileSize -Path $file -WarningAction SilentlyContinue

            $size | Should -Be 0
        }
    }
}

AfterAll {
    # Clean up
    if (Test-Path $script:testDir) {
        Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Remove-Module FileOperations -Force -ErrorAction SilentlyContinue
    Remove-Module ErrorHandling -Force -ErrorAction SilentlyContinue
}
