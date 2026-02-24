# ============================================
# Quality of Life Settings
# ============================================

# Fix unhandled ZLE widgets gracefully
zle -A history-incremental-search-backward menu-search 2>/dev/null || true
zle -A history-incremental-search-forward recent-paths 2>/dev/null || true

# Faster redraws for syntax highlighting
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)

# Autosuggestions color tweak (dim gray)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#666'

# Reduce command lag for large terminals (like Kitty)
export KEYTIMEOUT=10
