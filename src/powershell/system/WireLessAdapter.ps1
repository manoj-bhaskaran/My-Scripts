# This script restarts the Wi-Fi adapter without asking for confirmation

# Restart the Wi-Fi adapter without asking for confirmation
Restart-NetAdapter -InterfaceDescription 'Wi-Fi' -Confirm:$false
