# ============================================
# Aliases
# ============================================

# Git shortcuts
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'

#windows boot
alias boot_windows='sudo bootctl set-oneshot auto-windows && sudo reboot'

# Vesktop (Wayland + PipeWire capture compatibility)
alias vesktop='/opt/Vesktop/vesktop --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer --ozone-platform=wayland --disable-gpu-memory-buffer-video-frames'

# Sunshine instance switcher
alias sunshine='~/Scripts/sunshine-switch.sh'
