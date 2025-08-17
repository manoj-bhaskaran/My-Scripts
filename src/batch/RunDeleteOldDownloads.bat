@echo off
setlocal
:: ------------------------------------------------------------
:: DeleteOldDownloads launcher - Version 2.1
:: - Prefers PowerShell 7 (pwsh.exe), falls back to Windows PS.
:: - Invokes DeleteOldDownloads.ps1 with -Recurse -DeleteEmptyFolders.
:: - Shows a MessageBox on failure; returns the script's exit code.
:: ------------------------------------------------------------

:: Path to the PowerShell script
set "SCRIPT=C:\Users\manoj\Documents\Scripts\src\powershell\DeleteOldDownloads.ps1"

:: Try to locate PowerShell 7 from PATH (first match)
set "RUNNER="
for /f "delims=" %%I in ('where pwsh 2^>nul') do (
  set "RUNNER=%%I"
  goto :have_runner
)

:: If not in PATH, try the default install path
if not defined RUNNER if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
  set "RUNNER=C:\Program Files\PowerShell\7\pwsh.exe"
)

:have_runner
:: Fallback to Windows PowerShell if pwsh isn't available
if not defined RUNNER set "RUNNER=powershell"

:: Run the cleanup script with required switches
"%RUNNER%" -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT%" -Recurse -DeleteEmptyFolders
set "RC=%ERRORLEVEL%"

:: On failure, show a MessageBox to the interactive user
if not "%RC%"=="0" (
  "%RUNNER%" -NoLogo -NoProfile -Command ^
    "Add-Type -AssemblyName System.Windows.Forms; " ^
    "[System.Windows.Forms.MessageBox]::Show(" ^
    "'The file deletion task failed. Check the log for details.'," ^
    "'DeleteOldDownloads Failed') | Out-Null"
)

endlocal & exit /b %RC%
