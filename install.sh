#!/bin/bash

# Dotfiles Install Script
# Uses GNU Stow to symlink dotfiles to home directory

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# All available packages
PACKAGES=(
    "zsh"
    "oh-my-zsh"
    "git"
    "ssh"
    "kitty"
    "ghostty"
    "vscode"
    "zed"
    "nvim"
    "btop"
    "neofetch"
    "pop-shell"
    "profile"
    "opencode"
)

# Files with secrets - not stowed, copied from template on first setup
SENSITIVE_FILES=(
    "ssh/.ssh/config"
    "zed/.config/zed/settings.json"
)

# Check for stow
check_stow() {
    if ! command -v stow &> /dev/null; then
        print_warning "GNU Stow is not installed."
        
        if command -v brew &> /dev/null; then
            print_status "Installing stow via Homebrew..."
            brew install stow
        elif command -v apt &> /dev/null; then
            print_status "Installing stow via apt..."
            sudo apt install -y stow
        elif command -v pacman &> /dev/null; then
            print_status "Installing stow via pacman..."
            sudo pacman -S --noconfirm stow
        else
            print_error "Could not install stow. Please install it manually."
            exit 1
        fi
    fi
    print_success "GNU Stow is available"
}

# Check and install zsh
check_zsh() {
    if ! command -v zsh &> /dev/null; then
        print_warning "Zsh is not installed."
        
        if command -v brew &> /dev/null; then
            print_status "Installing zsh via Homebrew..."
            brew install zsh
        elif command -v apt &> /dev/null; then
            print_status "Installing zsh via apt..."
            sudo apt install -y zsh
        elif command -v pacman &> /dev/null; then
            print_status "Installing zsh via pacman..."
            sudo pacman -S --noconfirm zsh
        else
            print_error "Could not install zsh. Please install it manually."
            exit 1
        fi
    fi
    print_success "Zsh is available"
}

# Set zsh as default shell
set_default_shell() {
    local zsh_path
    zsh_path=$(which zsh)
    
    if [[ "$SHELL" == *"zsh"* ]]; then
        print_success "Zsh is already the default shell"
        return
    fi
    
    print_status "Setting zsh as default shell..."
    
    if ! grep -q "$zsh_path" /etc/shells; then
        print_status "Adding $zsh_path to /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
    fi
    
    chsh -s "$zsh_path"
    print_success "Default shell set to zsh (restart terminal to apply)"
}

# Check for Oh My Zsh
check_omz() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        print_warning "Oh My Zsh is not installed."
        read -p "Install Oh My Zsh? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Installing Oh My Zsh..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            print_success "Oh My Zsh installed"
        else
            print_warning "Skipping oh-my-zsh package (requires Oh My Zsh)"
            SKIP_OMZ=true
        fi
    fi
}

# Backup existing files
backup_existing() {
    local package=$1
    local target_dir="$HOME"
    
    # Find all files that would be stowed
    for file in $(find "$DOTFILES_DIR/$package" -type f 2>/dev/null); do
        local rel_path="${file#$DOTFILES_DIR/$package/}"
        local target="$target_dir/$rel_path"
        
        if [[ -e "$target" && ! -L "$target" ]]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$rel_path")"
            cp "$target" "$BACKUP_DIR/$rel_path"
            print_warning "Backed up: $target"
        fi
    done
}

setup_sensitive_file() {
    local file=$1
    local template="${file}.template"
    local target="$HOME/${file#*/}"
    
    if [[ ! -f "$DOTFILES_DIR/$template" ]]; then
        return
    fi
    
    if [[ -f "$target" ]]; then
        print_success "Sensitive file exists, not overwriting: $target"
        return
    fi
    
    mkdir -p "$(dirname "$target")"
    cp "$DOTFILES_DIR/$template" "$target"
    print_warning "Created from template (fill in your values): $target"
}

# Stow a package
stow_package() {
    local package=$1
    
    if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
        print_warning "Package '$package' not found, skipping..."
        return
    fi
    
    # Skip oh-my-zsh if not installed
    if [[ "$package" == "oh-my-zsh" && "$SKIP_OMZ" == "true" ]]; then
        print_warning "Skipping oh-my-zsh (Oh My Zsh not installed)"
        return
    fi
    
    backup_existing "$package"
    
    print_status "Stowing $package..."
    cd "$DOTFILES_DIR"
    stow -v --adopt "$package" -t "$HOME" 2>&1 | grep -v "^LINK:" || true
    
    # --adopt brings local changes into repo (keeps your actual values)
    # Do NOT git checkout here - that would overwrite real configs with templates
    
    print_success "Stowed $package"
}

# Unstow a package
unstow_package() {
    local package=$1
    
    print_status "Unstowing $package..."
    cd "$DOTFILES_DIR"
    stow -v -D "$package" -t "$HOME" 2>&1 | grep -v "^UNLINK:" || true
    print_success "Unstowed $package"
}

# Show help
show_help() {
    echo "Dotfiles Installation Script"
    echo ""
    echo "Usage: $0 [command] [packages...]"
    echo ""
    echo "Commands:"
    echo "  install [packages]    Install specified packages (default: all)"
    echo "  remove [packages]     Remove specified packages"
    echo "  list                  List available packages"
    echo "  help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install            # Install all packages"
    echo "  $0 install zsh git    # Install only zsh and git"
    echo "  $0 remove vscode      # Remove vscode package"
    echo ""
    echo "Available packages:"
    printf '  %s\n' "${PACKAGES[@]}"
}

# List packages
list_packages() {
    echo "Available packages:"
    for pkg in "${PACKAGES[@]}"; do
        if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
            echo -e "  ${GREEN}✓${NC} $pkg"
        else
            echo -e "  ${RED}✗${NC} $pkg (not found)"
        fi
    done
}

# Main
main() {
    local command="${1:-install}"
    shift || true
    
    case "$command" in
        install)
            check_stow
            check_zsh
            check_omz
            set_default_shell
            
            local pkgs=("$@")
            [[ ${#pkgs[@]} -eq 0 ]] && pkgs=("${PACKAGES[@]}")
            
            echo ""
            print_status "Installing packages: ${pkgs[*]}"
            echo ""
            
            for pkg in "${pkgs[@]}"; do
                stow_package "$pkg"
            done
            
            echo ""
            print_status "Setting up sensitive files..."
            for file in "${SENSITIVE_FILES[@]}"; do
                setup_sensitive_file "$file"
            done
            
            echo ""
            print_success "Installation complete!"
            echo ""
            echo "Note: You may need to:"
            echo "  1. Fill in placeholders in ~/.ssh/config"
            echo "  2. Fill in API keys in ~/.config/zed/settings.json"
            echo "  3. Restart your shell: exec zsh"
            ;;
        remove)
            local pkgs=("$@")
            [[ ${#pkgs[@]} -eq 0 ]] && { print_error "Specify packages to remove"; exit 1; }
            
            for pkg in "${pkgs[@]}"; do
                unstow_package "$pkg"
            done
            ;;
        list)
            list_packages
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
