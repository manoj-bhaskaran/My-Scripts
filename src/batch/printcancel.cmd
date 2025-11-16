@echo off
setlocal enabledelayedexpansion

:: ------------------------------------------------------------
:: Printer Spooler Maintenance Utility - Version 2.0.0
:: - Stops the Windows Print Spooler service
:: - Clears print queue files (.shd and .spl)
:: - Restarts the Print Spooler service
:: - Implements standardized logging framework (Issue #338)
:: ------------------------------------------------------------

:: Initialize logging
set "SCRIPT_NAME=%~n0"
set "LOG_DIR=%~dp0logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Get current date for log file name (YYYY-MM-DD format)
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value') do set "dt=%%i"
set "LOG_DATE=%dt:~0,4%-%dt:~4,2%-%dt:~6,2%"
set "LOG_FILE=%LOG_DIR%\%SCRIPT_NAME%_batch_%LOG_DATE%.log"

call :LogInfo "Script started - Beginning printer spooler maintenance"

:: Stop the spooler service
call :LogInfo "Stopping Windows Print Spooler service"
net stop spooler >> "%LOG_FILE%" 2>&1
if "%ERRORLEVEL%"=="0" (
  call :LogInfo "Print Spooler service stopped successfully"
) else (
  call :LogError "Failed to stop Print Spooler service - Exit code: %ERRORLEVEL%"
)

:: Delete .shd files
call :LogInfo "Deleting spool header files (.shd)"
del %systemroot%\system32\spool\printers\*.shd >> "%LOG_FILE%" 2>&1
if "%ERRORLEVEL%"=="0" (
  call :LogInfo "Spool header files (.shd) deleted successfully"
) else (
  call :LogWarning "Error deleting .shd files or no files found - Exit code: %ERRORLEVEL%"
)

:: Delete .spl files
call :LogInfo "Deleting spool data files (.spl)"
del %systemroot%\system32\spool\printers\*.spl >> "%LOG_FILE%" 2>&1
if "%ERRORLEVEL%"=="0" (
  call :LogInfo "Spool data files (.spl) deleted successfully"
) else (
  call :LogWarning "Error deleting .spl files or no files found - Exit code: %ERRORLEVEL%"
)

:: Start the spooler service
call :LogInfo "Starting Windows Print Spooler service"
net start spooler >> "%LOG_FILE%" 2>&1
if "%ERRORLEVEL%"=="0" (
  call :LogInfo "Print Spooler service started successfully"
) else (
  call :LogError "Failed to start Print Spooler service - Exit code: %ERRORLEVEL%"
  set "RC=%ERRORLEVEL%"
  goto :end
)

call :LogInfo "Printer spooler maintenance completed successfully"
set "RC=0"

:end
endlocal & exit /b %RC%

:: ============================================================
:: Logging Functions
:: ============================================================

:LogInfo
call :WriteLog "INFO" "%~1"
exit /b

:LogWarning
call :WriteLog "WARNING" "%~1"
exit /b

:LogError
call :WriteLog "ERROR" "%~1"
exit /b

:WriteLog
setlocal
:: Get timestamp, timezone, hostname, and PID using PowerShell
for /f "usebackq tokens=1,2,3,4 delims=|" %%a in (`powershell -NoProfile -Command "$ts=Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'; $tz=(Get-TimeZone).StandardName; $host=$env:COMPUTERNAME; $pid=$PID; Write-Output \"$ts|$tz|$host|$pid\""`) do (
    set "TS=%%a"
    set "TZ=%%b"
    set "HOST=%%c"
    set "PID=%%d"
)
set "LEVEL=%~1"
set "MSG=%~2"
>> "%LOG_FILE%" echo [%TS% %TZ%] [%LEVEL%] [%SCRIPT_NAME%.cmd] [%HOST%] [%PID%] %MSG%
endlocal
exit /b