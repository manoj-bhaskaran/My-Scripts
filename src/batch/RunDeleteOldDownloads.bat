@echo off
setlocal
:: ------------------------------------------------------------
:: DeleteOldDownloads launcher - Version 2.0
:: - Prefers PowerShell 7 (pwsh.exe), falls back to Windows PS.
:: - Calls DeleteOldDownloads.ps1 with -Recurse and -DeleteEmptyFolders.
:: - Shows a MessageBox on failure; returns the script's exit code.
:: ------------------------------------------------------------

:: Path to the PowerShell script
set "SCRIPT=C:\Users\manoj\Documents\Scripts\src\powershell\DeleteOldDownloads.ps1"

:: Try to locate PowerShell 7 first (PATH), then common install path
set "RUNNER="
where pwsh >nul 2>&1 && for /f "delims=" %%I in ('where pwsh') do (
  set "RUNNER=%%I"
)
if not defined RUNNER if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
  set "RUNNER=C:\Program Files\PowerShell\7\pwsh.exe"
)

:: Fallback to Windows PowerShell if pwsh isn't available
if not defined RUNNER set "RUNNER=powershell"

:: Run the cleanup script with required switches
"%RUNNER%" -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT%" -Recurse -DeleteEmptyFolders
set "RC=%ERRORLEVEL%"

:: On failure, show a simple MessageBox to the interactive user
if not "%RC%"=="0" (
  "%RUNNER%" -NoLogo -NoProfile -Command ^
    "Add-Type -AssemblyName System.Windows.Forms; " ^
    "[System.Windows.Forms.MessageBox]::Show(" ^
    "'The file deletion task failed. Check the log for details.'," ^
    " 'Task Failed') | Out-Null"
)

endlocal & exit /b %RC%
