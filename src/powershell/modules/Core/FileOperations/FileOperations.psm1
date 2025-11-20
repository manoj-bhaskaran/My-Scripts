############################################################
# FileOperations.psm1
# Standardized file operations with retry logic
############################################################

<#
.SYNOPSIS
    Provides file operation utilities with built-in retry logic.

.DESCRIPTION
    This module provides reusable functions for common file operations
    (copy, move, remove, rename) with automatic retry on failure and
    other file system utilities.

.NOTES
    Version: 1.0.0
    Date: 2025-11-20
    License: Apache License, Version 2.0
    Requires: ErrorHandling module for retry logic
#>

# Import ErrorHandling module for retry logic
$ErrorHandlingPath = Join-Path $PSScriptRoot "..\ErrorHandling\ErrorHandling.psm1"
if (Test-Path $ErrorHandlingPath) {
    Import-Module $ErrorHandlingPath -Force
}

function Copy-FileWithRetry {
    <#
    .SYNOPSIS
        Copies a file with automatic retry on failure.

    .DESCRIPTION
        Copies a file from source to destination with built-in retry logic
        to handle transient failures like file locks or network issues.

    .PARAMETER Source
        Source file path (must exist).

    .PARAMETER Destination
        Destination file path.

    .PARAMETER Force
        Overwrite destination file if it exists (default: $true).

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 2).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 60).

    .EXAMPLE
        Copy-FileWithRetry -Source "C:\source\file.txt" -Destination "D:\dest\file.txt"

    .EXAMPLE
        Copy-FileWithRetry -Source $src -Destination $dst -MaxRetries 5 -RetryDelay 1

    .OUTPUTS
        [bool] True if copy succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $false)]
        [switch]$Force = $true,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 60
    )

    if (-not (Test-Path $Source)) {
        throw "Source file not found: $Source"
    }

    $operation = {
        Copy-Item -Path $Source -Destination $Destination -Force:$Force -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
                        -Description "Copy '$Source' to '$Destination'" `
                        -RetryDelay $RetryDelay `
                        -RetryCount $MaxRetries `
                        -MaxBackoff $MaxBackoff
    } else {
        # Fallback if ErrorHandling module not available
        & $operation
    }

    return $true
}

function Move-FileWithRetry {
    <#
    .SYNOPSIS
        Moves a file with automatic retry on failure.

    .DESCRIPTION
        Moves a file from source to destination with built-in retry logic.

    .PARAMETER Source
        Source file path (must exist).

    .PARAMETER Destination
        Destination file path.

    .PARAMETER Force
        Overwrite destination file if it exists (default: $true).

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 2).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 60).

    .EXAMPLE
        Move-FileWithRetry -Source "C:\temp\file.txt" -Destination "D:\archive\file.txt"

    .OUTPUTS
        [bool] True if move succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $false)]
        [switch]$Force = $true,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 60
    )

    if (-not (Test-Path $Source)) {
        throw "Source file not found: $Source"
    }

    $operation = {
        Move-Item -Path $Source -Destination $Destination -Force:$Force -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
                        -Description "Move '$Source' to '$Destination'" `
                        -RetryDelay $RetryDelay `
                        -RetryCount $MaxRetries `
                        -MaxBackoff $MaxBackoff
    } else {
        & $operation
    }

    return $true
}

function Remove-FileWithRetry {
    <#
    .SYNOPSIS
        Removes a file with automatic retry on failure.

    .DESCRIPTION
        Deletes a file with built-in retry logic to handle locked files.

    .PARAMETER Path
        Path to the file to remove.

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 2).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 60).

    .EXAMPLE
        Remove-FileWithRetry -Path "C:\temp\file.txt"

    .OUTPUTS
        [bool] True if removal succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 60
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Path does not exist: $Path"
        return $true
    }

    $operation = {
        Remove-Item -Path $Path -Force -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
                        -Description "Remove '$Path'" `
                        -RetryDelay $RetryDelay `
                        -RetryCount $MaxRetries `
                        -MaxBackoff $MaxBackoff
    } else {
        & $operation
    }

    return $true
}

function Rename-FileWithRetry {
    <#
    .SYNOPSIS
        Renames a file with automatic retry on failure.

    .DESCRIPTION
        Renames a file with built-in retry logic.

    .PARAMETER Path
        Path to the file to rename.

    .PARAMETER NewName
        New name for the file (not full path, just the name).

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 2).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 60).

    .EXAMPLE
        Rename-FileWithRetry -Path "C:\temp\oldname.txt" -NewName "newname.txt"

    .OUTPUTS
        [bool] True if rename succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$NewName,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 60
    )

    if (-not (Test-Path $Path)) {
        throw "Path does not exist: $Path"
    }

    $operation = {
        Rename-Item -Path $Path -NewName $NewName -Force -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
                        -Description "Rename '$Path' to '$NewName'" `
                        -RetryDelay $RetryDelay `
                        -RetryCount $MaxRetries `
                        -MaxBackoff $MaxBackoff
    } else {
        & $operation
    }

    return $true
}

function Test-FolderWritable {
    <#
    .SYNOPSIS
        Tests if a folder is writable.

    .DESCRIPTION
        Tests whether a folder exists and is writable by attempting to create
        a temporary file. Optionally creates the folder if it doesn't exist.

    .PARAMETER Path
        Path to the folder to test.

    .PARAMETER SkipCreate
        Don't create the folder if it doesn't exist (default: $false).

    .EXAMPLE
        if (Test-FolderWritable "C:\temp") {
            Write-Host "Folder is writable"
        }

    .EXAMPLE
        if (Test-FolderWritable "C:\logs" -SkipCreate) {
            Write-Host "Folder exists and is writable"
        }

    .OUTPUTS
        [bool] True if folder is writable, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$SkipCreate
    )

    if (-not (Test-Path $Path)) {
        if ($SkipCreate) {
            return $false
        }

        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
        catch {
            Write-Warning "Failed to create directory '$Path': $_"
            return $false
        }
    }

    # Test write permissions by creating a temporary file
    $testFile = Join-Path $Path ".write_test_$([guid]::NewGuid().ToString('N'))"

    try {
        [IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Verbose "Folder '$Path' is not writable: $_"
        return $false
    }
}

function Add-ContentWithRetry {
    <#
    .SYNOPSIS
        Appends content to a file with retry logic.

    .DESCRIPTION
        Appends text content to a file with automatic retry on failure.
        Useful for logging scenarios where file might be temporarily locked.

    .PARAMETER Path
        Path to the file.

    .PARAMETER Value
        Content to append.

    .PARAMETER MaxRetries
        Maximum retry attempts (default: 3).

    .PARAMETER RetryDelay
        Base delay between retries in seconds (default: 1).

    .PARAMETER MaxBackoff
        Maximum backoff delay in seconds (default: 30).

    .PARAMETER Encoding
        File encoding (default: UTF8).

    .EXAMPLE
        Add-ContentWithRetry -Path "C:\logs\app.log" -Value "Log entry"

    .OUTPUTS
        [bool] True if append succeeded, throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 1,

        [Parameter(Mandatory = $false)]
        [int]$MaxBackoff = 30,

        [Parameter(Mandatory = $false)]
        [string]$Encoding = "UTF8"
    )

    # Ensure parent directory exists
    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    $operation = {
        Add-Content -Path $Path -Value $Value -Encoding $Encoding -ErrorAction Stop
    }

    if (Get-Command Invoke-WithRetry -ErrorAction SilentlyContinue) {
        Invoke-WithRetry -Operation $operation `
                        -Description "Append content to '$Path'" `
                        -RetryDelay $RetryDelay `
                        -RetryCount $MaxRetries `
                        -MaxBackoff $MaxBackoff `
                        -LogErrors $false
    } else {
        & $operation
    }

    return $true
}

function New-DirectoryIfNotExists {
    <#
    .SYNOPSIS
        Creates a directory if it doesn't exist.

    .DESCRIPTION
        Ensures a directory exists by creating it if necessary.
        Returns $true if directory was created, $false if it already existed.

    .PARAMETER Path
        Path to the directory.

    .EXAMPLE
        New-DirectoryIfNotExists "C:\temp\logs"

    .OUTPUTS
        [bool] True if directory was created, False if already existed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path $Path) {
        return $false
    }

    try {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        return $true
    }
    catch {
        throw "Failed to create directory '$Path': $_"
    }
}

function Get-FileSize {
    <#
    .SYNOPSIS
        Gets the size of a file in bytes.

    .DESCRIPTION
        Returns the size of a file in bytes. Returns 0 if file doesn't exist.

    .PARAMETER Path
        Path to the file.

    .EXAMPLE
        $size = Get-FileSize "C:\temp\file.txt"

    .OUTPUTS
        [long] File size in bytes.
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return 0
    }

    try {
        $file = Get-Item -Path $Path -ErrorAction Stop
        return $file.Length
    }
    catch {
        Write-Warning "Failed to get size of '$Path': $_"
        return 0
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Copy-FileWithRetry',
    'Move-FileWithRetry',
    'Remove-FileWithRetry',
    'Rename-FileWithRetry',
    'Test-FolderWritable',
    'Add-ContentWithRetry',
    'New-DirectoryIfNotExists',
    'Get-FileSize'
)
