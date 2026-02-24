#!/usr/bin/env bash
# swaybg-launch.sh — reads ~/.config/wallpaper.conf and launches swaybg
# To change wallpaper: edit WALLPAPER= in ~/.config/wallpaper.conf, then re-run this script

CONF="${HOME}/.config/wallpaper.conf"

if [[ ! -f "$CONF" ]]; then
    echo "wallpaper.conf not found at $CONF" >&2
    exit 1
fi

# Source the config (expands ~ properly)
source "$CONF"

# Expand ~ manually in case it wasn't expanded by source
WALLPAPER="${WALLPAPER/#\~/$HOME}"

if [[ ! -f "$WALLPAPER" ]]; then
    echo "Wallpaper file not found: $WALLPAPER" >&2
    exit 1
fi

MODE="${MODE:-fill}"

# Kill existing swaybg instance
pkill -x swaybg 2>/dev/null
sleep 0.2

exec swaybg -i "$WALLPAPER" -m "$MODE"
