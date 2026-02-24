# Dotfiles

My personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick Start

```bash
git clone git@github.com:Englios/dotfiles.git ~/Codes/dotfiles
cd ~/Codes/dotfiles
./install.sh
```

## Packages

| Package | Description |
|---------|-------------|
| `zsh` | Zsh config with modular setup |
| `oh-my-zsh` | Custom hex theme for Oh My Zsh |
| `git` | Git config + Jujutsu (jj) config |
| `ssh` | SSH host configurations |
| `kitty` | Kitty terminal + Spacedust theme |
| `ghostty` | Ghostty terminal config |
| `vscode` | VS Code settings & keybindings |
| `zed` | Zed editor settings |
| `nvim` | Neovim config (LazyVim) |
| `btop` | btop system monitor (ayu theme) |
| `neofetch` | Neofetch config |
| `pop-shell` | Pop Shell tiling config |
| `profile` | Login shell profile |
| `opencode` | OpenCode AI config |

## Usage

```bash
./install.sh install              # Install all packages
./install.sh install zsh git      # Install specific packages
./install.sh remove vscode        # Remove a package
./install.sh list                 # List available packages
```

## Syncing

**How it works:** Stow creates symlinks from your home directory into this repo. When you edit `~/.config/nvim/init.lua`, you're editing the repo file directly.

| Action | Command |
|--------|---------|
| Push changes to GitHub | `cd ~/Codes/dotfiles && jj describe -m "message" && jj bookmark set master -r @ && jj git push` |
| Pull changes from GitHub | `cd ~/Codes/dotfiles && jj git fetch && jj rebase -d master@origin` |
| Reset local to remote | `cd ~/Codes/dotfiles && jj git fetch && jj abandon @ && jj new master@origin` |

**Workflow:**
1. Edit configs on your system as usual (changes are already in the repo via symlinks)
2. Commit and push with jj when ready
3. On another machine: `git pull` (or `jj git fetch`) and run `./install.sh` to create symlinks

## Sensitive Files

Files with secrets are gitignored and never overwritten by `install.sh`. Templates are provided:

| File | Template |
|------|----------|
| `~/.ssh/config` | `ssh/.ssh/config.template` |
| `~/.config/zed/settings.json` | `zed/.config/zed/settings.json.template` |

On first install, templates are copied automatically. Fill in your values afterward.

## Post-Install

After installation on a new machine, fill in your values:

1. **SSH Config** (`~/.ssh/config`):
   - `YOUR_HOMELAB_LOCAL_IP` - Local network IP
   - `YOUR_HOMELAB_TAILSCALE_IP` - Tailscale IP
   - `YOUR_HOMELAB_USER` - SSH username

2. **Zed Settings** (`~/.config/zed/settings.json`):
   - `YOUR_BRAVE_API_KEY`
   - `YOUR_EXA_API_KEY`
   - `YOUR_GITHUB_PAT`
   - `YOUR_CONTEXT7_API_KEY`

## Dependencies

- [GNU Stow](https://www.gnu.org/software/stow/)
- [Oh My Zsh](https://ohmyz.sh/) (for zsh/oh-my-zsh packages)
- [Homebrew](https://brew.sh/) (recommended for Linux)

## Structure

```
dotfiles/
├── package-name/
│   ├── .config/
│   │   └── app/
│   │       └── config-file
│   └── .dotfile
└── install.sh
```

Each package mirrors the home directory structure. Stow creates symlinks from `~` to the files in each package.
