# Dotfiles

Personal macOS development environment configuration.

## Quick Start

```bash
# 1. Install Xcode Command Line Tools
xcode-select --install

# 2. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Clone and install
git clone https://github.com/SomtoUgeh/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./install.sh

# 4. Configure private settings
cp templates/zshrc-private.template ~/.zshrc.private
# Edit ~/.zshrc.private with your API keys

# 5. Apply macOS settings
./macos/defaults.sh

# 6. Restart terminal
exec zsh
```

## Directory Structure

The install script creates this folder layout:

```
~/
├── code/                    # All code projects (CDPATH enabled)
│   ├── myrepo/              # Main repo
│   └── myrepo--feature/     # Worktree (created by gwt)
├── bin/                     # Custom scripts (in PATH)
├── Pictures/Screenshots/    # macOS screenshots location
├── .config/                 # XDG config home
└── .ssh/                    # SSH keys (700 permissions)
```

**CDPATH** is configured so you can `cd projectname` from anywhere to jump to `~/code/projectname`.

## What's Included

### Shell
- **Zsh** with Oh My Zsh framework
- **Starship** prompt (cross-shell, fast)
- Plugins: fzf-tab, zsh-autosuggestions, fast-syntax-highlighting
- Custom aliases and functions

### Editors
- **Cursor** (primary) - AI-powered VSCode fork
- **Zed** - Fast, modern editor
- **VSCode** - Shares config with Cursor

### Terminal
- **Ghostty** - GPU-accelerated terminal
- **iTerm2** - Backup terminal

### Development Tools
- **fnm** - Fast Node Manager
- **uv** - Python package manager
- **ast-grep** - Structural code search
- **delta** - Better git diffs

### CLI Utilities
- **eza** - Modern ls with icons
- **bat** - Better cat with syntax highlighting
- **fzf** - Fuzzy finder
- **ripgrep** - Fast grep
- **gh** - GitHub CLI

## Repository Structure

```
dotfiles/
├── install.sh              # Main installation script
├── Brewfile                # Homebrew packages
├── README.md
├── shell/                  # Shell configurations
│   ├── .zshrc
│   ├── .zshenv
│   └── .zprofile
├── git/                    # Git configuration
│   ├── .gitconfig
│   └── .gitignore_global
├── config/
│   ├── cursor/             # Cursor/VSCode settings
│   ├── ghostty/            # Ghostty terminal config
│   ├── starship/           # Starship prompt config
│   ├── zed/                # Zed editor settings
│   └── gh/                 # GitHub CLI config
├── claude/                 # Claude Code configuration
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── commands/
│   └── agents/
├── scripts/                # Custom scripts (linked to ~/bin)
│   ├── gwt                 # Git worktree manager
│   ├── gcauto              # Git commit automation
│   └── ...
├── macos/
│   └── defaults.sh         # macOS system preferences
└── templates/              # Templates for sensitive files
    ├── zshrc-private.template
    ├── ssh-config.template
    └── aws-config.template
```

## Key Configurations

### Keyboard Speed
macOS defaults are too slow for coding. `macos/defaults.sh` sets:
- `KeyRepeat = 1` (fastest, 15ms between repeats)
- `InitialKeyRepeat = 15` (shortest delay before repeat)

### Editor Keybindings
Shared across Cursor/VSCode/Zed:
- `cmd+t` - Toggle terminal
- `shift+down/up` - Duplicate line
- `alt+up` - Move line up
- `alt+d` - Delete line
- `cmd+q cmd+f` - Quick text search

### Git
- Auto rebase on pull
- Delta pager for diffs
- Case-sensitive file handling
- Useful aliases: `a`, `c`, `p`, `l`, `rh`, `b`, `co`, `amend`, `undo`

## Manual Steps

### After Installation

1. **SSH Keys** - Copy from old machine or generate new:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ssh-add --apple-use-keychain ~/.ssh/id_ed25519
   pbcopy < ~/.ssh/id_ed25519.pub  # Add to GitHub
   ```

2. **Git Identity** - Set if not using global:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

3. **Private Config** - Add API keys to `~/.zshrc.private`

### App Store Apps
Install manually: 1Password, Xcode, etc.

### Browser Extensions
Install from respective stores after browser setup.

## Updating

```bash
cd ~/code/dotfiles
git pull
./install.sh  # Re-run to update symlinks
```

## Troubleshooting

### Zsh completion issues
```bash
rm -f ~/.zcompdump*
exec zsh
```

### Keyboard speed not applied
Log out and back in, or restart the Mac.

### Symlinks not working
```bash
rm ~/.zshrc  # Remove existing file
./install.sh  # Re-run install
```
