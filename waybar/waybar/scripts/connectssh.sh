#!/bin/bash

hostname=$(cat "$HOME/.config/.secrets/hostname.txt" 2>/dev/null)
ip=$(tailscale ip -4 "$hostname" 2>/dev/null)

if [ -z "$hostname" ]; then
    echo "No hostname configured in ~/.config/.secrets/hostname.txt"
    read -p "Press enter to close..."
    exit 1
fi

echo "Connecting to $hostname: $ip..."
read -rp "Enter username: " username
ssh "$username"@"$ip"
