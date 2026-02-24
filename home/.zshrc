# ============================================
# Modular Zsh Configuration
# ============================================
# Config files organized in ~/.config/zsh/
# Original backed up to ~/.zshrc.backup

# Load configuration in order
for config in ~/.config/zsh/{env,homebrew,omz,plugins,aliases,functions,settings}.zsh; do
  [ -f "$config" ] && source "$config"
done
