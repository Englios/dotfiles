#!/bin/bash

hostnames=($(cat "$HOME/.config/.secrets/hostnames.txt" 2>/dev/null))
sshhost=($(cat "$HOME/.config/.secrets/hostname.txt" 2>/dev/null))

if [ -z "$hostnames" ]; then
    hostnames=("$sshhost")
fi

css_class="green"
online_count=0
online_section=""
offline_section=""

for hostname in "${hostnames[@]}"; do
    ip=$(tailscale ip -4 "$hostname" 2>/dev/null)
    status=$(tailscale status 2>/dev/null | awk -v h="$hostname" '$0 ~ h {print}')


    if [ "$sshhost" = "$hostname" ]; then
        label="* ${hostname}"
    else
        label="  ${hostname}"
    fi

    if echo "$status" | grep -q "offline" || [ -z "$status" ]; then
        if [ "$sshhost" = "$hostname" ]; then
            css_class=red
        fi
        offline_section+="${label}: ${ip}"$'\n'
    else
        online_count=$((online_count + 1))
        online_section+="${label}: ${ip}"$'\n'
    fi
done


tooltip=""
if [ -n "$online_section" ]; then
    tooltip+=" Online"$'\n'
    tooltip+="${online_section}"
fi
if [ -n "$offline_section" ]; then
    [ -n "$online_section" ] && tooltip+=$'\n'
    tooltip+=" Offline"$'\n'
    tooltip+="${offline_section}"
fi

tooltip="${tooltip%$'\n'}"

text="󰖂 ${online_count}/${#hostnames[@]}"

jq -nc \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$css_class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
