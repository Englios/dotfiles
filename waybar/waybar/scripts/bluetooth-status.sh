#!/bin/bash

if ! bluetoothctl show | grep -q "Powered: yes"; then
    jq -nc '{text: "󰂲", tooltip: "Bluetooth off", class: "off"}'
    exit 0
fi

# Get connected devices directly via D-Bus - no StartDiscovery triggered
connected_json=$(dbus-send --system --print-reply \
    --dest=org.bluez / \
    org.freedesktop.DBus.ObjectManager.GetManagedObjects 2>/dev/null)

mapfile -t connected < <(echo "$connected_json" | \
    awk '/object path.*dev_/{mac=$NF} /"Connected"/{f=1} f && /boolean true/{print mac; f=0}' | \
    tr -d '"' | sed 's|/org/bluez/hci[0-9]*/dev_||')

if [ ${#connected[@]} -eq 0 ]; then
    jq -nc '{text: "󰂯", tooltip: "No devices connected", class: "on"}'
    exit 0
fi

tooltip=" Connected"$'\n'
for dev_path in "${connected[@]}"; do
    mac=$(echo "$dev_path" | tr '_' ':')
    name=$(echo "$connected_json" | awk -v d="$dev_path" \
        '$0~d{f=1} f && /"Name"/{gsub(/.*string "/,""); gsub(/"$/,""); print; exit}')
    [ -z "$name" ] && name="$mac"
    battery=$(bluetoothctl info "$mac" 2>/dev/null | \
        awk '/Battery Percentage/ {gsub(/[()]/,"",$NF); print $NF"%"}')
    if [ -n "$battery" ]; then
        tooltip+="  ${name}: ${battery}"$'\n'
    else
        tooltip+="  ${name}"$'\n'
    fi
done
tooltip="${tooltip%$'\n'}"

count=${#connected[@]}
jq -nc \
    --arg text "󰂱 ${count}" \
    --arg tooltip "$tooltip" \
    '{text: $text, tooltip: $tooltip, class: "connected"}'
