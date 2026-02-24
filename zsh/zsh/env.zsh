# ============================================
# Environment Variables & PATH Configuration
# ============================================

# Base PATH
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Go
export PATH="$HOME/go/bin:$PATH"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

#DotNet
export DOTNET_ROOT="/home/linuxbrew/.linuxbrew/opt/dotnet/libexec"

# Bun completions
[ -s "/home/alif-pc/.bun/_bun" ] && source "/home/alif-pc/.bun/_bun"
