#!/bin/bash

if ! bluetoothctl show | grep -q "Powered: yes"; then
    jq -nc '{text: "󰂲", tooltip: "Bluetooth off", class: "off"}'
    exit 0
fi

mapfile -t connected < <(bluetoothctl devices Connected)

if [ ${#connected[@]} -eq 0 ]; then
    jq -nc '{text: "󰂯", tooltip: "No devices connected", class: "on"}'
    exit 0
fi

tooltip=" Connected"$'\n'
for entry in "${connected[@]}"; do
    mac=$(echo "$entry" | awk '{print $2}')
    name=$(echo "$entry" | cut -d' ' -f3-)
    battery=$(bluetoothctl info "$mac" 2>/dev/null | awk '/Battery Percentage/ {gsub(/[()]/,"",$NF); print $NF"%"}')
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
