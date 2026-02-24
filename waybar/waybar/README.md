# Waybar Setup for Niri

Custom Waybar v0.15.0 configuration for Pop!_OS 24.04 with Niri compositor.

![Waybar Screenshot](../../images/Waybar.png)

## Based On

[00Darxk/dotfiles](https://github.com/00Darxk/dotfiles/tree/main/waybar)

## Features

- **Niri integration**: Window title, workspaces, layout-aware
- **Modules**:
  - Clock, Network, Bluetooth
  - Niri: window title, workspaces
  - Custom: fuzzel launcher, tailscale, updates, github, media, GPU, CPU, power, lock, swaync
  - PulseAudio (with microphone), Tray

## Structure

```
waybar/
├── config.jsonc      # Main config (includes module files)
├── style.css         # Main styles
├── modules/
│   ├── custom/       # Custom module configs
│   ├── extra/        # Extra configs
│   └── niri/         # Niri-specific modules
└── scripts/          # Helper scripts
```

## Requirements

- Waybar v0.15.0 (built from source)
- Niri compositor
- playerctl
- pactl (for audio)
- fuzzel (launcher)

## Launch

```bash
WAYLAND_DISPLAY=wayland-1 waybar --config ~/.config/waybar/config.jsonc --style ~/.config/waybar/style.css
```

## Reload

```bash
pkill -9 waybar && WAYLAND_DISPLAY=wayland-1 waybar --config ~/.config/waybar/config.jsonc --style ~/.config/waybar/style.css > /tmp/waybar.log 2>&1 &
```
