<#
.SYNOPSIS
    Unit tests for FileOperations module

.DESCRIPTION
    Pester tests for the FileOperations PowerShell module
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

        { Copy-FileWithRetry -Source $source -Destination $dest } | Should -Throw
    }

    It "Creates destination directory if needed" {
        $source = Join-Path $script:testDir "source2.txt"
        $dest = Join-Path $script:testDir "subdir\dest.txt"

        "test content" | Out-File -FilePath $source -NoNewline

        $result = Copy-FileWithRetry -Source $source -Destination $dest

        $result | Should -Be $true
        Test-Path $dest | Should -Be $true
    }
}

Describe "Move-FileWithRetry" {
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

        { Move-FileWithRetry -Source $source -Destination $dest } | Should -Throw
    }
}

Describe "Remove-FileWithRetry" {
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
}

Describe "Rename-FileWithRetry" {
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

        { Rename-FileWithRetry -Path $file -NewName "new.txt" } | Should -Throw
    }
}

Describe "Test-FolderWritable" {
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
}

Describe "Add-ContentWithRetry" {
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
}

Describe "New-DirectoryIfNotExists" {
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
        $dir = Join-Path $script:testDir "a\b\c"

        $result = New-DirectoryIfNotExists -Path $dir

        $result | Should -Be $true
        Test-Path $dir | Should -Be $true
    }
}

Describe "Get-FileSize" {
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
}

AfterAll {
    # Clean up
    if (Test-Path $script:testDir) {
        Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Remove-Module FileOperations -Force -ErrorAction SilentlyContinue
    Remove-Module ErrorHandling -Force -ErrorAction SilentlyContinue
}
