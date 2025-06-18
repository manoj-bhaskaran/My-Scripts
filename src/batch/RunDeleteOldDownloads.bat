@echo off
powershell -ExecutionPolicy Bypass -File "C:\Users\manoj\Documents\Scripts\src\powershell\DeleteOldDownloads.ps1"
if %errorlevel% neq 0 (
    powershell -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('The file deletion task failed. Check the log for details.', 'Task Failed')"
)
