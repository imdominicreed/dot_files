#!/bin/bash
# Shows the current WSL IP and the Windows command to set DNS

WSL_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

echo "WSL IP: ${WSL_IP}"
echo ""
echo "Run this in Windows PowerShell (Admin) to enable *.dev.local:"
echo ""
echo "  Set-DnsClientServerAddress -InterfaceAlias \"vEthernet (WSL)\" -ServerAddresses \"${WSL_IP}\",\"8.8.8.8\""
echo ""
echo "Or if that adapter name doesn't work, find it with:"
echo "  Get-NetAdapter | Where-Object {\$_.Name -like \"*WSL*\"}"
