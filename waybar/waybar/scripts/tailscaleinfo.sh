#!/bin/bash

hostnames=($(cat "$HOME/.config/.secrets/hostnames.txt" 2>/dev/null))
sshhost=($(cat "$HOME/.config/.secrets/hostname.txt" 2>/dev/null))

if [ -z "$hostnames" ]; then
    hostnames=("$sshhost")
fi

tooltip=""
css_class="green"
online_count=0

for i in "${!hostnames[@]}"; do
    hostname="${hostnames[$i]}"

    ip=$(tailscale ip -4 "$hostname" 2>/dev/null)
    status=$(tailscale status 2>/dev/null | awk -v h="$hostname" '$0 ~ h {print $NF}')

    if [ "$status" = "offline" ] || [ -z "$status" ]; then
        if [ "$sshhost" = "$hostname" ]; then
            css_class=red
        fi
        status_icon=""
    else
        online_count=$((online_count + 1))
        status_icon=""
    fi

    if [ "$sshhost" = "$hostname" ]; then
        tooltip+=">  ${hostname}: ${ip} ${status_icon}"
    else
        tooltip+="   ${hostname}: ${ip} ${status_icon}"
    fi

    j=$((i + 1))
    if [ $j -lt ${#hostnames[@]} ]; then
        tooltip+=$'\n'
    fi
done

# Short display: icon + online count
text=" ${online_count}/${#hostnames[@]}"

jq -nc \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$css_class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
