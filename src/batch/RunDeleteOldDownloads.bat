@echo off
setlocal enabledelayedexpansion

:: ------------------------------------------------------------
:: Remove-OldDownload launcher - Version 4.0.0
:: - Prefers PowerShell 7 (pwsh.exe), falls back to Windows PS.
:: - Invokes Remove-OldDownload.ps1 with -Recurse -DeleteEmptyFolders.
:: - Shows a MessageBox on failure; returns the script's exit code.
:: - Implements standardized logging framework (Issue #338)
:: - Removed hardcoded paths for portability (Issue #513)
:: ------------------------------------------------------------

:: Initialize logging
set "SCRIPT_NAME=%~n0"
set "LOG_DIR=%~dp0logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Get current date for log file name (YYYY-MM-DD format)
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value') do set "dt=%%i"
set "LOG_DATE=%dt:~0,4%-%dt:~4,2%-%dt:~6,2%"
set "LOG_FILE=%LOG_DIR%\%SCRIPT_NAME%_batch_%LOG_DATE%.log"

:: Get script directory and navigate to repository root
set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%..\.."

:: Build path to PowerShell script using relative path
set "SCRIPT=%REPO_ROOT%\src\powershell\system\Remove-OldDownload.ps1"

:: Validate script exists
if not exist "%SCRIPT%" (
    call :LogError "PowerShell script not found: %SCRIPT%"
    echo Error: Script not found: %SCRIPT%
    echo Please check the repository structure.
    endlocal & exit /b 1
)

call :LogInfo "Using PowerShell script: %SCRIPT%"
call :LogInfo "Script started - Searching for PowerShell runtime"

:: Try to locate PowerShell 7 from PATH (first match)
set "RUNNER="
for /f "delims=" %%I in ('where pwsh 2^>nul') do (
  set "RUNNER=%%I"
  goto :have_runner
)

:: If not in PATH, try the default install path
if not defined RUNNER if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
  set "RUNNER=C:\Program Files\PowerShell\7\pwsh.exe"
  call :LogInfo "Found PowerShell 7 at default location"
)

:have_runner
:: Fallback to Windows PowerShell if pwsh isn't available
if not defined RUNNER (
  set "RUNNER=powershell"
  call :LogInfo "Using Windows PowerShell (fallback)"
) else (
  call :LogInfo "Using PowerShell 7: !RUNNER!"
)

call :LogInfo "Executing Remove-OldDownload.ps1 with -Recurse -DeleteEmptyFolders"

:: Run the cleanup script with required switches
"%RUNNER%" -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT%" -Recurse -DeleteEmptyFolders
set "RC=%ERRORLEVEL%"

:: Log the result
if "%RC%"=="0" (
  call :LogInfo "Script completed successfully - Exit code: %RC%"
) else (
  call :LogError "Script failed with exit code: %RC%"
)

:: On failure, show a MessageBox to the interactive user
if not "%RC%"=="0" (
  call :LogInfo "Displaying error message to user"
  "%RUNNER%" -NoLogo -NoProfile -Command ^
    "Add-Type -AssemblyName System.Windows.Forms; " ^
    "[System.Windows.Forms.MessageBox]::Show(" ^
    "'The file deletion task failed. Check the log for details.'," ^
    "'DeleteOldDownloads Failed') | Out-Null"
)

call :LogInfo "Script execution completed"
endlocal & exit /b %RC%

:: ============================================================
:: Logging Functions
:: ============================================================

:LogInfo
call :WriteLog "INFO" "%~1"
exit /b

:LogError
call :WriteLog "ERROR" "%~1"
exit /b

:WriteLog
setlocal
:: Get timestamp, timezone, hostname, and PID using PowerShell
for /f "usebackq tokens=1,2,3,4 delims=;" %%a in (`powershell -NoProfile -Command "$ts=Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'; $tz=(Get-TimeZone).StandardName; $hostname=$env:COMPUTERNAME; $pid=$PID; Write-Output \"$ts;$tz;$hostname;$pid\""`) do (
    set "TS=%%a"
    set "TZ=%%b"
    set "HOST=%%c"
    set "PID=%%d"
)
set "LEVEL=%~1"
set "MSG=%~2"
>> "%LOG_FILE%" echo [%TS% %TZ%] [%LEVEL%] [%SCRIPT_NAME%.bat] [%HOST%] [%PID%] %MSG%
endlocal
exit /b
