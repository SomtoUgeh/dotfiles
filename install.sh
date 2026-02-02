#!/usr/bin/env bash

# Dotfiles Installation Script
# Creates symlinks from home directory to dotfiles in this repo

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "================================================"
echo "Dotfiles Installation"
echo "================================================"
echo "Installing from: $DOTFILES_DIR"
echo ""

# =============================================================================
# Create directory structure
# =============================================================================
echo "Setting up directory structure..."

# Main directories
mkdir -p "$HOME/code"              # All code projects
mkdir -p "$HOME/bin"               # Custom scripts
mkdir -p "$HOME/Pictures/Screenshots"  # Screenshots location

# Config directories
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo -e "${GREEN}✓${NC} Directory structure ready"
echo ""

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"

    # Create parent directory if needed
    local target_dir=$(dirname "$target")
    if [ ! -d "$target_dir" ]; then
        echo -e "${YELLOW}Creating directory: $target_dir${NC}"
        mkdir -p "$target_dir"
    fi

    # Back up existing file (not symlink)
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo -e "${YELLOW}Backing up: $target${NC}"
        mv "$target" "$target.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Remove outdated symlink
    if [ -L "$target" ]; then
        current_link=$(readlink "$target")
        if [ "$current_link" != "$source" ]; then
            echo -e "${YELLOW}Removing outdated symlink: $target${NC}"
            rm "$target"
        fi
    fi

    # Create symlink
    if [ ! -e "$target" ]; then
        echo -e "${GREEN}Linking: $target -> $source${NC}"
        ln -s "$source" "$target"
    else
        echo -e "✓ Already linked: $target"
    fi
}

# =============================================================================
# Oh My Zsh
# =============================================================================
echo ""
echo "Setting up Oh My Zsh..."

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "✓ Oh My Zsh already installed"
fi

# Install Oh My Zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]; then
    echo "Installing fzf-tab plugin..."
    git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
else
    echo "✓ fzf-tab already installed"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions plugin..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
else
    echo "✓ zsh-autosuggestions already installed"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
    echo "Installing fast-syntax-highlighting plugin..."
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
else
    echo "✓ fast-syntax-highlighting already installed"
fi

# =============================================================================
# Shell configurations
# =============================================================================
echo ""
echo "Setting up shell configurations..."

create_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/shell/.zshenv" "$HOME/.zshenv"
create_symlink "$DOTFILES_DIR/shell/.zprofile" "$HOME/.zprofile"

# =============================================================================
# Git configurations
# =============================================================================
echo ""
echo "Setting up git configurations..."

create_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
create_symlink "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

# =============================================================================
# npm configuration
# =============================================================================
echo ""
echo "Setting up npm configuration..."

if [ -f "$DOTFILES_DIR/npm/.npmrc" ]; then
    create_symlink "$DOTFILES_DIR/npm/.npmrc" "$HOME/.npmrc"
fi

# =============================================================================
# Claude Code configurations
# =============================================================================
echo ""
echo "Setting up Claude Code configurations..."

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.claude/hooks"

create_symlink "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
create_symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"

# Statusline and file suggestion scripts
if [ -f "$DOTFILES_DIR/claude/statusline.sh" ]; then
    create_symlink "$DOTFILES_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
    chmod +x "$HOME/.claude/statusline.sh" 2>/dev/null || true
fi
if [ -f "$DOTFILES_DIR/claude/file-suggestion.sh" ]; then
    create_symlink "$DOTFILES_DIR/claude/file-suggestion.sh" "$HOME/.claude/file-suggestion.sh"
    chmod +x "$HOME/.claude/file-suggestion.sh" 2>/dev/null || true
fi

# Hooks
if [ -d "$DOTFILES_DIR/claude/hooks" ]; then
    for hook in "$DOTFILES_DIR/claude/hooks/"*; do
        if [ -f "$hook" ]; then
            hook_name=$(basename "$hook")
            create_symlink "$hook" "$HOME/.claude/hooks/$hook_name"
            chmod +x "$HOME/.claude/hooks/$hook_name" 2>/dev/null || true
        fi
    done
fi

# Commands and agents
if [ -d "$DOTFILES_DIR/claude/commands" ]; then
    create_symlink "$DOTFILES_DIR/claude/commands" "$HOME/.claude/commands"
fi
if [ -d "$DOTFILES_DIR/claude/agents" ]; then
    create_symlink "$DOTFILES_DIR/claude/agents" "$HOME/.claude/agents"
fi

# =============================================================================
# Starship prompt
# =============================================================================
echo ""
echo "Setting up Starship configuration..."

create_symlink "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"

# =============================================================================
# Fish shell (if used)
# =============================================================================
if [ -d "$DOTFILES_DIR/config/fish" ]; then
    echo ""
    echo "Setting up Fish configuration..."
    mkdir -p "$HOME/.config/fish/conf.d"
    create_symlink "$DOTFILES_DIR/config/fish/config.fish" "$HOME/.config/fish/config.fish"
fi

# =============================================================================
# Ghostty terminal
# =============================================================================
echo ""
echo "Setting up Ghostty configuration..."

GHOSTTY_CONFIG_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$GHOSTTY_CONFIG_DIR"
create_symlink "$DOTFILES_DIR/config/ghostty/config" "$GHOSTTY_CONFIG_DIR/config"

# =============================================================================
# Zed editor
# =============================================================================
echo ""
echo "Setting up Zed configuration..."

ZED_CONFIG_DIR="$HOME/.config/zed"
mkdir -p "$ZED_CONFIG_DIR"
create_symlink "$DOTFILES_DIR/config/zed/settings.json" "$ZED_CONFIG_DIR/settings.json"
create_symlink "$DOTFILES_DIR/config/zed/keymap.json" "$ZED_CONFIG_DIR/keymap.json"

# =============================================================================
# Cursor/VSCode
# =============================================================================
echo ""
echo "Setting up Cursor configuration..."

CURSOR_CONFIG_DIR="$HOME/Library/Application Support/Cursor/User"
mkdir -p "$CURSOR_CONFIG_DIR"
create_symlink "$DOTFILES_DIR/config/cursor/settings.json" "$CURSOR_CONFIG_DIR/settings.json"
create_symlink "$DOTFILES_DIR/config/cursor/keybindings.json" "$CURSOR_CONFIG_DIR/keybindings.json"

# Also link to VSCode if installed (separate settings for different font)
VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
if [ -d "$VSCODE_CONFIG_DIR" ]; then
    echo "Setting up VSCode configuration..."
    create_symlink "$DOTFILES_DIR/config/vscode-settings.json" "$VSCODE_CONFIG_DIR/settings.json"
    create_symlink "$DOTFILES_DIR/config/cursor/keybindings.json" "$VSCODE_CONFIG_DIR/keybindings.json"
fi

# =============================================================================
# GitHub CLI
# =============================================================================
echo ""
echo "Setting up GitHub CLI configuration..."

if [ -d "$DOTFILES_DIR/config/gh" ]; then
    create_symlink "$DOTFILES_DIR/config/gh" "$HOME/.config/gh"
fi

# =============================================================================
# Custom scripts
# =============================================================================
echo ""
echo "Setting up custom scripts in ~/bin..."

mkdir -p "$HOME/bin"

for script in "$DOTFILES_DIR/scripts/"*; do
    if [ -f "$script" ]; then
        script_name=$(basename "$script")
        # Skip .DS_Store
        if [ "$script_name" != ".DS_Store" ]; then
            create_symlink "$script" "$HOME/bin/$script_name"
            chmod +x "$HOME/bin/$script_name" 2>/dev/null || true
        fi
    fi
done

# =============================================================================
# Homebrew packages
# =============================================================================
echo ""
echo "Installing Homebrew packages..."

if command -v brew &> /dev/null; then
    echo "Running brew bundle install..."
    cd "$DOTFILES_DIR"
    brew bundle install
else
    echo -e "${RED}Homebrew not found. Please install Homebrew first:${NC}"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

# =============================================================================
# Final steps
# =============================================================================
echo ""
echo "================================================"
echo -e "${GREEN}Installation complete!${NC}"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Copy private configuration template:"
echo "   cp templates/zshrc-private.template ~/.zshrc.private"
echo "   # Then edit ~/.zshrc.private with your API keys"
echo ""
echo "2. Apply macOS system preferences:"
echo "   ./macos/defaults.sh"
echo ""
echo "3. Restart your terminal or run: exec zsh"
echo ""
echo "For detailed instructions, see README.md"
