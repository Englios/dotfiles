#!/bin/bash

# Dotfiles Install Script
# Uses GNU Stow to symlink dotfiles to home directory

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Resolved from .stowrc (falls back to $HOME when not set)
STOW_TARGET="$HOME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Interactive selector theme
UI_RESET='\033[0m'
UI_BG_BLACK='\033[40m'
UI_FG_WHITE='\033[97m'
UI_FG_DIM='\033[90m'
UI_FG_CYAN='\033[96m'
UI_FG_GREEN='\033[92m'
UI_FG_RED='\033[91m'
UI_FG_YELLOW='\033[93m'
UI_FG_BLACK='\033[30m'
UI_BG_BLUE='\033[44m'

# Full-screen selector state
UI_ACTIVE=0

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

resolve_stow_target() {
    local target_line target_value

    target_line=$(grep -E '^--target=' "$DOTFILES_DIR/.stowrc" 2>/dev/null | tail -n 1 || true)
    target_value="${target_line#--target=}"

    if [[ -n "$target_value" && "$target_value" != "$target_line" ]]; then
        # Expand leading ~
        STOW_TARGET="${target_value/#\~/$HOME}"
    else
        STOW_TARGET="$HOME"
    fi
}

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

# Interactive selection result (used when install runs without package args)
CHOSEN_PACKAGES=()

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
    local target_dir="$STOW_TARGET"
    
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
    stow -v --adopt "$package" 2>&1 | grep -v "^LINK:" || true
    
    # --adopt brings local changes into repo (keeps your actual values)
    # Do NOT git checkout here - that would overwrite real configs with templates
    
    print_success "Stowed $package"
}

# Unstow a package
unstow_package() {
    local package=$1
    
    print_status "Unstowing $package..."
    cd "$DOTFILES_DIR"
    stow -v -D "$package" 2>&1 | grep -v "^UNLINK:" || true
    print_success "Unstowed $package"
}

# Show help
show_help() {
    echo "Dotfiles Installation Script"
    echo ""
    echo "Usage: $0 [command] [packages...]"
    echo ""
    echo "Commands:"
    echo "  install [packages]    Install/stow specified packages"
    echo "  remove [packages]     Remove specified packages"
    echo "  list                  List available packages"
    echo "  help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install            # Interactive package selection"
    echo "  $0 install all        # Install all packages"
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

is_valid_package() {
    local package=$1
    local known

    for known in "${PACKAGES[@]}"; do
        [[ "$known" == "$package" ]] && return 0
    done

    return 1
}

validate_requested_packages() {
    local invalid=()
    local package

    for package in "$@"; do
        if ! is_valid_package "$package"; then
            invalid+=("$package")
        fi
    done

    if [[ ${#invalid[@]} -gt 0 ]]; then
        print_error "Unknown package(s): ${invalid[*]}"
        print_status "Run '$0 list' to see available packages"
        return 1
    fi

    return 0
}

count_selected_packages() {
    local count=0
    local i

    for i in "${!PACKAGES[@]}"; do
        [[ "${PACKAGE_FLAGS[$i]}" -eq 1 ]] && ((count++))
    done

    echo "$count"
}

ui_init() {
    # Alternate screen + hide cursor (TUI feel)
    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    UI_ACTIVE=1
}

ui_cleanup() {
    # Always restore terminal state
    echo -ne "$UI_RESET"
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    UI_ACTIVE=0
}

ui_clear_fullscreen_black() {
    local rows cols r

    rows=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 80)

    printf '\033[H'
    for ((r = 0; r < rows; r++)); do
        printf '%b%*s%b\n' "$UI_BG_BLACK" "$cols" "" "$UI_RESET"
    done
    printf '\033[H'
}

render_package_selector() {
    local cursor=$1
    local i marker pointer selected_count
    local total page_size total_pages page_index page_start page_end
    local marker_color name_color line_prefix line_suffix display_name

    selected_count=$(count_selected_packages)
    total=${#PACKAGES[@]}
    page_size=${SELECTOR_PAGE_SIZE:-8}
    (( page_size < 1 )) && page_size=8

    total_pages=$(((total + page_size - 1) / page_size))
    page_index=$((cursor / page_size))
    page_start=$((page_index * page_size))
    page_end=$((page_start + page_size - 1))
    (( page_end >= total )) && page_end=$((total - 1))

    ui_clear_fullscreen_black
    echo -e "${UI_BG_BLACK}${UI_FG_CYAN}Dotfiles package selector${UI_RESET}"
    echo -e "${UI_BG_BLACK}${UI_FG_DIM}Move: ↑/↓ (or k/j) | Toggle: Enter | Start: s | All on: a | All off: n | Prev/Next page: [/ ] | Quit: q${UI_RESET}"
    echo -e "${UI_BG_BLACK}${UI_FG_DIM}Page $((page_index + 1))/${total_pages} • Showing $((page_start + 1))-$((page_end + 1)) of $total${UI_RESET}"
    echo ""

    for ((i = page_start; i <= page_end; i++)); do
        if [[ "${PACKAGE_FLAGS[$i]}" -eq 1 ]]; then
            marker="[x]"
            marker_color="$UI_FG_GREEN"
        else
            marker="[ ]"
            marker_color="$UI_FG_RED"
        fi

        if [[ "$i" -eq "$cursor" ]]; then
            pointer=">"
            line_prefix="${UI_BG_BLUE}${UI_FG_BLACK}"
            line_suffix="$UI_RESET"
        else
            pointer=" "
            line_prefix="${UI_BG_BLACK}${UI_FG_WHITE}"
            line_suffix="$UI_RESET"
        fi

        if [[ -d "$DOTFILES_DIR/${PACKAGES[$i]}" ]]; then
            display_name="${PACKAGES[$i]}"
            name_color="$UI_FG_WHITE"
        else
            display_name="${PACKAGES[$i]} (missing)"
            name_color="$UI_FG_YELLOW"
        fi

        printf '%b %s %b%s%b %b%s%b%b\n' \
            "$line_prefix" \
            "$pointer" \
            "$marker_color" "$marker" "$line_prefix" \
            "$name_color" "$display_name" "$line_prefix" \
            "$line_suffix"
    done

    echo ""
    echo -e "${UI_BG_BLACK}${UI_FG_CYAN}Selected: $selected_count/$total${UI_RESET}"
}

select_packages_interactive() {
    local idx cursor key page_size
    local selected_count
    local -a PACKAGE_FLAGS=()

    CHOSEN_PACKAGES=()
    page_size=${SELECTOR_PAGE_SIZE:-8}
    (( page_size < 1 )) && page_size=8

    ui_init
    trap '[[ "$UI_ACTIVE" -eq 1 ]] && ui_cleanup' EXIT INT TERM

    # Default to all selected; Enter toggles individual packages on/off.
    for idx in "${!PACKAGES[@]}"; do
        PACKAGE_FLAGS[$idx]=1
    done

    cursor=0

    while true; do
        render_package_selector "$cursor"
        IFS= read -rsn1 key

        # Handle arrow keys (escape sequence)
        if [[ "$key" == $'\e' ]]; then
            IFS= read -rsn2 key || true
            case "$key" in
                "[A") cursor=$(((cursor - 1 + ${#PACKAGES[@]}) % ${#PACKAGES[@]})) ;;
                "[B") cursor=$(((cursor + 1) % ${#PACKAGES[@]})) ;;
            esac
            continue
        fi

        case "$key" in
            "")
                if [[ "${PACKAGE_FLAGS[$cursor]}" -eq 1 ]]; then
                    PACKAGE_FLAGS[$cursor]=0
                else
                    PACKAGE_FLAGS[$cursor]=1
                fi
                ;;
            "k")
                cursor=$(((cursor - 1 + ${#PACKAGES[@]}) % ${#PACKAGES[@]}))
                ;;
            "j")
                cursor=$(((cursor + 1) % ${#PACKAGES[@]}))
                ;;
            "a")
                for idx in "${!PACKAGES[@]}"; do
                    PACKAGE_FLAGS[$idx]=1
                done
                ;;
            "n")
                for idx in "${!PACKAGES[@]}"; do
                    PACKAGE_FLAGS[$idx]=0
                done
                ;;
            "[")
                cursor=$((cursor - page_size))
                (( cursor < 0 )) && cursor=0
                ;;
            "]")
                cursor=$((cursor + page_size))
                (( cursor >= ${#PACKAGES[@]} )) && cursor=$((${#PACKAGES[@]} - 1))
                ;;
            "s"|"S")
                selected_count=$(count_selected_packages)
                if [[ "$selected_count" -eq 0 ]]; then
                    print_warning "Select at least one package before continuing"
                    sleep 1
                else
                    break
                fi
                ;;
            "q"|"Q")
                print_error "Installation cancelled"
                exit 1
                ;;
        esac
    done

    for idx in "${!PACKAGES[@]}"; do
        if [[ "${PACKAGE_FLAGS[$idx]}" -eq 1 ]]; then
            CHOSEN_PACKAGES+=("${PACKAGES[$idx]}")
        fi
    done

    ui_cleanup
    trap - EXIT INT TERM
}

# Main
main() {
    local command="${1:-install}"
    shift || true
    
    case "$command" in
        install)
            resolve_stow_target
            check_stow
            check_zsh
            check_omz
            set_default_shell
            
            local pkgs=("$@")
            if [[ ${#pkgs[@]} -eq 0 ]]; then
                select_packages_interactive
                pkgs=("${CHOSEN_PACKAGES[@]}")
            elif [[ ${#pkgs[@]} -eq 1 && "${pkgs[0]}" == "all" ]]; then
                pkgs=("${PACKAGES[@]}")
            fi

            [[ ${#pkgs[@]} -eq 0 ]] && { print_error "No packages selected"; exit 1; }
            validate_requested_packages "${pkgs[@]}" || exit 1
            
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
            resolve_stow_target
            local pkgs=("$@")
            [[ ${#pkgs[@]} -eq 0 ]] && { print_error "Specify packages to remove"; exit 1; }
            validate_requested_packages "${pkgs[@]}" || exit 1
            
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
