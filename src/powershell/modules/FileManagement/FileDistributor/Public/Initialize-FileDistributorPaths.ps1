# Initialize-FileDistributorPaths.ps1 - Resolve effective log and state file paths (public module function)

function Initialize-FileDistributorPaths {
    param(
        [string]$UserLogPath,
        [string]$UserStatePath,
        [string]$CallerScriptRoot
    )

    # Expose the caller's script root to Resolve-PathWithFallback via module-scope $script:ScriptRoot
    $script:ScriptRoot = $CallerScriptRoot

    $localAppData = $env:LOCALAPPDATA
    $tempRoot = $env:TEMP

    $defaultLogWindows  = Join-Path -Path (Join-Path $localAppData 'FileDistributor\logs')  -ChildPath 'FileDistributor-log.txt'
    $defaultLogTemp     = Join-Path -Path (Join-Path $tempRoot     'FileDistributor\logs')  -ChildPath 'FileDistributor-log.txt'
    $defaultLogScriptRel = 'logs\FileDistributor-log.txt'

    $defaultStateWindows  = Join-Path -Path (Join-Path $localAppData 'FileDistributor\state') -ChildPath 'FileDistributor-State.json'
    $defaultStateTemp     = Join-Path -Path (Join-Path $tempRoot     'FileDistributor\state') -ChildPath 'FileDistributor-State.json'
    $defaultStateScriptRel = 'state\FileDistributor-State.json'

    $logFilePath   = Resolve-PathWithFallback -UserPath $UserLogPath `
        -ScriptRelativePath $defaultLogScriptRel `
        -WindowsDefaultPath $defaultLogWindows `
        -TempFallbackPath   $defaultLogTemp

    $stateFilePath = Resolve-PathWithFallback -UserPath $UserStatePath `
        -ScriptRelativePath $defaultStateScriptRel `
        -WindowsDefaultPath $defaultStateWindows `
        -TempFallbackPath   $defaultStateTemp

    Resolve-FilePathIfDirectory -Path ([ref]$logFilePath)   -DefaultFileName 'FileDistributor-log.txt'
    Resolve-FilePathIfDirectory -Path ([ref]$stateFilePath) -DefaultFileName 'FileDistributor-State.json'

    Initialize-FilePath -FilePath $logFilePath   -CreateFile
    Initialize-FilePath -FilePath $stateFilePath

    return @{
        LogFilePath   = $logFilePath
        StateFilePath = $stateFilePath
    }
}
