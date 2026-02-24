#!/bin/bash

threshold_yellow=15
threshold_red=100

list_updates=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g")

if ! updates=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l); then
    updates=0
fi

# Hide module when no updates
if [ "$updates" -eq 0 ]; then
    exit 1
fi

tooltip="System Updates (${updates} package/s):"$'\n'"<small>${list_updates}</small>"

if [ "$updates" -lt "$threshold_yellow" ]; then
    css_class="green"
elif [ "$updates" -lt "$threshold_red" ]; then
    css_class="yellow"
else
    css_class="red"
fi

jq -nc \
    --arg text "$updates" \
    --arg tooltip "$tooltip" \
    --arg class "$css_class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
