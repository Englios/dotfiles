#!/bin/bash

# Dotfiles Install Script
# Uses GNU Stow to symlink dotfiles into home/config directories

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

is_excluded_package_dir() {
    local name=$1
    local excluded

    for excluded in "${PACKAGE_EXCLUDES[@]}"; do
        [[ "$name" == "$excluded" ]] && return 0
    done

    return 1
}

discover_packages() {
    local dir name

    PACKAGES=()

    while IFS= read -r dir; do
        name="${dir##*/}"

        # Skip hidden folders and known non-package dirs.
        [[ "$name" == .* ]] && continue
        is_excluded_package_dir "$name" && continue

        PACKAGES+=("$name")
    done < <(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

    if [[ ${#PACKAGES[@]} -eq 0 ]]; then
        print_error "No packages found in $DOTFILES_DIR"
        exit 1
    fi
}

resolve_package_target() {
    local package=$1

    # If package contains top-level dotfiles/dirs (e.g. .zshrc/.ssh), target HOME.
    if find "$DOTFILES_DIR/$package" -mindepth 1 -maxdepth 1 -name ".*" | grep -q .; then
        echo "$HOME"
    else
        # Config-style packages target whatever .stowrc specifies (usually ~/.config).
        echo "$STOW_TARGET"
    fi
}

# Auto-discovered package list and explicit excludes.
PACKAGES=()
PACKAGE_EXCLUDES=(
    "images"
    "ssh.examples"
    "zed.examples"
)

# Interactive selection result (used when install runs without package args)
CHOSEN_PACKAGES=()
SELECTION_CANCELLED=0

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
    if ! is_valid_package "oh-my-zsh"; then
        return
    fi

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

detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v brew &> /dev/null; then
        echo "brew"
    else
        echo ""
    fi
}

get_system_packages_for_dotfile_package() {
    local package=$1
    local manager=$2

    case "$package" in
        zsh) printf '%s\n' "zsh" ;;
        git) printf '%s\n' "git" ;;
        nvim) printf '%s\n' "neovim" ;;
        kitty) printf '%s\n' "kitty" ;;
        btop) printf '%s\n' "btop" ;;
        neofetch) printf '%s\n' "neofetch" ;;
        fuzzel) printf '%s\n' "fuzzel" ;;
        niri) printf '%s\n' "niri" ;;
        waybar) printf '%s\n' "waybar" ;;
        ghostty)
            # Package availability varies widely by distro/repo.
            [[ "$manager" == "pacman" ]] && printf '%s\n' "ghostty"
            ;;
        pop-shell)
            if [[ "$manager" == "apt" ]]; then
                printf '%s\n' "gnome-shell-extension-pop-shell"
            elif [[ "$manager" == "pacman" ]]; then
                printf '%s\n' "pop-shell"
            fi
            ;;
        vscode)
            if [[ "$manager" == "apt" || "$manager" == "pacman" ]]; then
                printf '%s\n' "code"
            fi
            ;;
    esac
}

install_system_dependencies_for_packages() {
    local manager package
    local reply
    local -a deps all_deps
    local seen_deps=""

    if [[ "${SKIP_SYSTEM_INSTALL:-0}" == "1" ]]; then
        print_warning "Skipping system package install (SKIP_SYSTEM_INSTALL=1)"
        return
    fi

    manager=$(detect_package_manager)
    if [[ -z "$manager" ]]; then
        print_warning "No supported package manager found (apt/pacman/brew). Skipping system installs."
        return
    fi

    for package in "$@"; do
        mapfile -t deps < <(get_system_packages_for_dotfile_package "$package" "$manager")

        for dep in "${deps[@]}"; do
            if [[ " $seen_deps " != *" $dep "* ]]; then
                all_deps+=("$dep")
                seen_deps+=" $dep"
            fi
        done
    done

    if [[ ${#all_deps[@]} -eq 0 ]]; then
        print_status "No mapped system dependencies to install for selected packages."
        return
    fi

    echo ""
    print_status "System packages to install via $manager:"
    printf '  - %s\n' "${all_deps[@]}"
    echo ""

    if [[ -z "${AUTO_CONFIRM_INSTALL:-}" ]]; then
        read -r -p "Proceed with system package installation? [Y/n] " reply
        if [[ "$reply" =~ ^[Nn]$ ]]; then
            print_warning "Skipping system package installation by user choice"
            return
        fi
    fi

    print_status "Attempting system package installs via: $manager"

    if [[ "$manager" == "apt" ]]; then
        sudo apt update || print_warning "apt update failed; continuing with install attempts"
        sudo apt install -y "${all_deps[@]}" || print_warning "Some packages failed to install via apt"
    elif [[ "$manager" == "pacman" ]]; then
        sudo pacman -S --noconfirm --needed "${all_deps[@]}" || print_warning "Some packages failed to install via pacman"
    elif [[ "$manager" == "brew" ]]; then
        brew install "${all_deps[@]}" || print_warning "Some packages failed to install via brew"
    fi
}

confirm_stow_plan() {
    local reply pkg target

    echo ""
    print_status "Stow plan (symlink changes):"
    for pkg in "$@"; do
        target=$(resolve_package_target "$pkg")
        echo "  - $pkg -> $target"
    done
    echo ""

    read -r -p "Proceed with stowing selected packages? [Y/n] " reply
    if [[ "$reply" =~ ^[Nn]$ ]]; then
        return 1
    fi

    return 0
}

# Backup existing files
backup_existing() {
    local package=$1
    local target_dir
    target_dir=$(resolve_package_target "$package")
    
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
    local target_dir
    
    if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
        print_warning "Package '$package' not found, skipping..."
        return
    fi
    
    # Skip oh-my-zsh if not installed
    if [[ "$package" == "oh-my-zsh" && "$SKIP_OMZ" == "true" ]]; then
        print_warning "Skipping oh-my-zsh (Oh My Zsh not installed)"
        return
    fi

    target_dir=$(resolve_package_target "$package")
    
    backup_existing "$package"
    
    print_status "Stowing $package -> $target_dir..."
    cd "$DOTFILES_DIR"
    stow -v --adopt "$package" -t "$target_dir"
    
    # --adopt brings local changes into repo (keeps your actual values)
    # Do NOT git checkout here - that would overwrite real configs with templates
    
    print_success "Stowed $package"
}

# Unstow a package
unstow_package() {
    local package=$1
    local target_dir

    target_dir=$(resolve_package_target "$package")
    
    print_status "Unstowing $package from $target_dir..."
    cd "$DOTFILES_DIR"
    stow -v -D "$package" -t "$target_dir"
    print_success "Unstowed $package"
}

# Show help
show_help() {
    echo "Dotfiles Installation Script"
    echo ""
    echo "Usage: $0 [command] [packages...]"
    echo ""
    echo "Commands:"
    echo "  install [packages]    Attempt system install + stow specified packages"
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
    echo "Environment options:"
    echo "  SKIP_SYSTEM_INSTALL=1   Skip apt/pacman/brew install attempts"
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

ui_rule() {
    local cols char
    char=${1:-─}
    cols=$(tput cols 2>/dev/null || echo 80)
    printf '%*s' "$cols" '' | tr ' ' "$char"
}

render_package_selector() {
    local cursor=$1
    local i marker pointer selected_count
    local total page_size total_pages page_index page_start page_end
    local marker_color name_color line_prefix line_suffix display_name continue_color
    local row_number target_hint

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
    echo -e "${UI_BG_BLACK}${UI_FG_CYAN} Dotfiles Installer ${UI_RESET}"
    echo -e "${UI_BG_BLACK}${UI_FG_WHITE} Select packages to install and stow ${UI_RESET}"
    echo -e "${UI_BG_BLACK}${UI_FG_DIM}$(ui_rule)${UI_RESET}"
    echo -e "${UI_BG_BLACK}${UI_FG_DIM} Selected: ${selected_count}/${total}   •   Page: $((page_index + 1))/${total_pages}   •   Showing: $((page_start + 1))-$((page_end + 1)) ${UI_RESET}"
    echo -e "${UI_BG_BLACK}${UI_FG_DIM} Move ↑/↓ or j/k • Toggle Enter • Next/Prev page ]/[ ${UI_RESET}"
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

        row_number=$(printf '%02d' $((i + 1)))
        target_hint=$(resolve_package_target "${PACKAGES[$i]}")
        if [[ "$target_hint" == "$HOME" ]]; then
            target_hint="~"
        else
            target_hint="~/.config"
        fi

        printf '%b %s %b%s%b %b%s%b %b%s%b%b\n' \
            "$line_prefix" \
            "$pointer" \
            "$marker_color" "$marker" "$line_prefix" \
            "$name_color" "$row_number  $display_name" "$line_prefix" \
            "$UI_FG_DIM" "$target_hint" "$line_prefix" \
            "$line_suffix"
    done

    echo ""
    echo -e "${UI_BG_BLACK}${UI_FG_DIM}$(ui_rule)${UI_RESET}"

    if [[ "$selected_count" -gt 0 ]]; then
        continue_color="$UI_FG_GREEN"
    else
        continue_color="$UI_FG_RED"
    fi

    echo -e "${UI_BG_BLACK}${continue_color}[ c ] Continue${UI_RESET}  ${UI_BG_BLACK}${UI_FG_WHITE}[ Enter ] Toggle${UI_RESET}  ${UI_BG_BLACK}${UI_FG_WHITE}[ a ] All${UI_RESET}  ${UI_BG_BLACK}${UI_FG_WHITE}[ n ] None${UI_RESET}  ${UI_BG_BLACK}${UI_FG_WHITE}[ q ] Cancel${UI_RESET}"
}

select_packages_interactive() {
    local idx cursor key page_size
    local selected_count
    local -a PACKAGE_FLAGS=()

    CHOSEN_PACKAGES=()
    SELECTION_CANCELLED=0
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
            "c"|"C"|"s"|"S")
                selected_count=$(count_selected_packages)
                if [[ "$selected_count" -eq 0 ]]; then
                    print_warning "Select at least one package before continuing"
                    sleep 1
                else
                    break
                fi
                ;;
            "q"|"Q")
                SELECTION_CANCELLED=1
                break
                ;;
        esac
    done

    if [[ "$SELECTION_CANCELLED" -eq 1 ]]; then
        ui_cleanup
        trap - EXIT INT TERM
        return 1
    fi

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

    discover_packages
    
    case "$command" in
        install)
            resolve_stow_target
            check_stow
            check_zsh
            check_omz
            set_default_shell
            
            local pkgs=("$@")
            if [[ ${#pkgs[@]} -eq 0 ]]; then
                if ! select_packages_interactive; then
                    print_warning "Cancelled by user. No packages were installed or stowed."
                    exit 0
                fi
                pkgs=("${CHOSEN_PACKAGES[@]}")
            elif [[ ${#pkgs[@]} -eq 1 && "${pkgs[0]}" == "all" ]]; then
                pkgs=("${PACKAGES[@]}")
            fi

            [[ ${#pkgs[@]} -eq 0 ]] && { print_error "No packages selected"; exit 1; }
            validate_requested_packages "${pkgs[@]}" || exit 1
            
            echo ""
            print_status "Installing packages: ${pkgs[*]}"
            echo ""

            install_system_dependencies_for_packages "${pkgs[@]}"
            echo ""

            if ! confirm_stow_plan "${pkgs[@]}"; then
                print_warning "Stow cancelled by user. No symlinks were changed."
                exit 0
            fi
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
