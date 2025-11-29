# Retrieve the process associated with WLAN service
$WLANProc = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -eq "c:\windows\system32\svchost.exe -k LocalSystemNetworkRestricted -p" }

# Terminate the WLAN service process forcefully
Stop-Process -Id $WLANProc.ProcessId -Force

# Start the WLAN service
Start-Service WlanSvc
