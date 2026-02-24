#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNCIGNORE_FILE="$DOTFILES_DIR/.syncignore"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[SYNC]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

load_protected_paths() {
  if [ -f "$SYNCIGNORE_FILE" ]; then
    grep -v '^#' "$SYNCIGNORE_FILE" | grep -v '^$'
  fi
}

is_protected() {
  local path="$1"
  while IFS= read -r protected; do
    if [[ "$path" == *"$protected"* ]] || [[ "$path" == "$protected"* ]]; then
      return 0
    fi
  done < <(load_protected_paths)
  return 1
}

safe_cp() {
    local src="$1"
    local dst="$2"

    if is_protected "$src"; then
        print_error "REFUSED to copy protected path to repo: $src"
        return 1
    fi

    if [ "$(realpath "$src" 2>/dev/null)" = "$(realpath "$dst" 2>/dev/null)" ]; then
        return 0
    fi
    cp "$src" "$dst" 2>/dev/null && return 0
    return 1
}

safe_rsync() {
    local src="$1"
    local dst="$2"

    while IFS= read -r protected; do
        if [[ "$src" == *"$protected"* ]]; then
            print_error "REFUSED to rsync protected path: $src"
            return 1
        fi
    done < <(load_protected_paths)

    rsync -avL --exclude='.git' "$src" "$dst" > /dev/null
}

sync_to_repo() {
    print_status "Syncing from system to dotfiles repo..."

    local has_protected=0
    while IFS= read -r protected; do
        if [ -e "$HOME/$protected" ]; then
            has_protected=1
            break
        fi
    done < <(load_protected_paths)

    if [ $has_protected -eq 1 ]; then
        print_warning "Protected paths exist. Checking exclusions..."
    fi


    safe_cp ~/.zshrc "$DOTFILES_DIR/home/.zshrc" && print_success "home/.zshrc"
    safe_cp ~/.gitconfig "$DOTFILES_DIR/home/.gitconfig" && print_success "home/.gitconfig"
    safe_cp ~/.profile "$DOTFILES_DIR/home/.profile" && print_success "home/.profile"
    safe_cp ~/.oh-my-zsh/custom/themes/hex.zsh-theme "$DOTFILES_DIR/home/.oh-my-zsh/custom/themes/hex.zsh-theme" && print_success "home/.oh-my-zsh/hex.zsh-theme"


    safe_cp ~/.config/niri/config.kdl "$DOTFILES_DIR/niri/niri/config.kdl" && print_success "niri/config.kdl"
    safe_rsync ~/.config/niri/scripts/ "$DOTFILES_DIR/niri/niri/scripts/" && print_success "niri/scripts/*"
    safe_cp ~/.config/wallpaper.conf "$DOTFILES_DIR/niri/wallpaper.conf" && print_success "niri/wallpaper.conf"

    safe_rsync ~/.config/waybar/ "$DOTFILES_DIR/waybar/waybar/" && print_success "waybar/*"

    cp ~/.config/zsh/*.zsh "$DOTFILES_DIR/zsh/zsh/" 2>/dev/null && print_success "zsh/zsh/*"

    safe_rsync ~/.config/nvim/lua/ "$DOTFILES_DIR/nvim/nvim/lua/" && print_success "nvim/lua/*"
    safe_cp ~/.config/nvim/init.lua "$DOTFILES_DIR/nvim/nvim/init.lua" && print_success "nvim/init.lua"
    safe_cp ~/.config/nvim/lazy-lock.json "$DOTFILES_DIR/nvim/nvim/lazy-lock.json" && print_success "nvim/lazy-lock.json"

    cp ~/.config/kitty/*.conf "$DOTFILES_DIR/kitty/kitty/" 2>/dev/null && print_success "kitty/*"
    safe_cp ~/.config/ghostty/config "$DOTFILES_DIR/ghostty/ghostty/config" && print_success "ghostty/config"

    safe_cp ~/.config/Code/User/settings.json "$DOTFILES_DIR/vscode/Code/User/settings.json" && print_success "vscode/settings.json"
    safe_cp ~/.config/Code/User/keybindings.json "$DOTFILES_DIR/vscode/Code/User/keybindings.json" && print_success "vscode/keybindings.json"

    safe_cp ~/.config/jj/config.toml "$DOTFILES_DIR/git/jj/config.toml" && print_success "git/jj/config.toml"

    safe_cp ~/.config/btop/btop.conf "$DOTFILES_DIR/btop/btop/btop.conf" && print_success "btop/btop.conf"
    safe_cp ~/.config/neofetch/config.conf "$DOTFILES_DIR/neofetch/neofetch/config.conf" && print_success "neofetch/config.conf"
    safe_cp ~/.config/pop-shell/config.json "$DOTFILES_DIR/pop-shell/pop-shell/config.json" && print_success "pop-shell/config.json"

    safe_cp ~/.config/opencode/opencode.json "$DOTFILES_DIR/opencode/opencode/opencode.json" && print_success "opencode/opencode.json"
    safe_cp ~/.config/opencode/oh-my-opencode.json "$DOTFILES_DIR/opencode/opencode/oh-my-opencode.json" && print_success "opencode/oh-my-opencode.json"

    echo ""
    print_success "Sync complete! Review changes with: cd $DOTFILES_DIR && git diff"
}

sync_from_repo() {
    print_status "Syncing from dotfiles repo to system..."
    cd "$DOTFILES_DIR"

    backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    conflicts=0

    for package in */; do
        package="${package%/}"
        [[ "$package" == *.examples ]] && continue

        target_dir="$HOME/.config"
        [[ "$package" == "home" ]] && target_dir="$HOME"

        find "$package" \( -type f -o -type l \) -print0 2>/dev/null | while IFS= read -r -d '' file; do
            target="$target_dir/${file#$package/}"

            if is_protected "$target"; then
                print_error "REFUSED to process protected path: $target"
                continue
            fi

            if [ -e "$target" ] && [ ! -L "$target" ]; then
                conflicts=$((conflicts + 1))
                mkdir -p "$backup_dir"
                cp -r "$target" "$backup_dir/" 2>/dev/null || true
                rm -rf "$target"
                print_warning "Backed up conflicting file: $target"
            fi
        done
    done

    [ $conflicts -gt 0 ] && print_status "Backed up $conflicts conflicting files to $backup_dir"

    for package in */; do
        package="${package%/}"
        [[ "$package" == *.examples ]] && continue

        if [[ "$package" == "home" ]]; then
            stow -R "$package" -t "$HOME"
        else
            stow -R "$package"
        fi
    done
    print_success "All packages re-stowed"
}

show_help() {
    echo "Dotfiles Sync Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  push    Sync changes FROM system TO dotfiles repo"
    echo "  pull    Sync changes FROM dotfiles repo TO system (re-stow)"
    echo "  help    Show this help"
    echo ""
    echo "Configuration:"
    echo "  Edit .syncignore to add/remove protected paths"
    echo ""
    echo "Examples:"
    echo "  $0 push   # After editing configs, sync to repo before committing"
    echo "  $0 pull   # After git pull, apply changes to system"
}

case "${1:-help}" in
    push)
        sync_to_repo
        ;;
    pull)
        sync_from_repo
        ;;
    *)
        show_help
        ;;
esac
