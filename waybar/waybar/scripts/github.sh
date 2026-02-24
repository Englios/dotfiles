#!/bin/bash

threshold_yellow=5
threshold_red=50

token=$(cat "$HOME/.config/.secrets/notifications.token" 2>/dev/null)
if [ -z "$token" ]; then
    exit 1
fi

count=$(curl -s -u "$(git config user.name):${token}" https://api.github.com/notifications | jq '. | length' 2>/dev/null || echo 0)

# Hide module when no notifications
if [ "$count" -eq 0 ]; then
    exit 1
fi

css_class="green"
if [ "$count" -gt "$threshold_yellow" ]; then
    css_class="yellow"
fi
if [ "$count" -gt "$threshold_red" ]; then
    css_class="red"
fi

jq -nc \
    --arg text "$count" \
    --arg tooltip "GitHub Notifications: $count" \
    --arg class "$css_class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
