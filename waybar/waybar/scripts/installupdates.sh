#!/bin/bash

echo "Checking for updates..."
apt list --upgradable 2>/dev/null | grep -v "Listing..."
echo ""
read -rp "Download and install updates? (y/n): " UPD
if [[ "$UPD" == "Y" || "$UPD" == "y" ]]; then
    echo 'Lunametal2' | sudo -S apt update && echo 'Lunametal2' | sudo -S apt upgrade -y
fi
