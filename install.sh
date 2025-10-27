#!/usr/bin/env bash

# Dotfiles Installation Script
# This script creates symlinks from the home directory to dotfiles in this repo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "================================================"
echo "Dotfiles Installation"
echo "================================================"
echo "Installing from: $DOTFILES_DIR"
echo ""

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"

    # Create parent directory if it doesn't exist
    local target_dir=$(dirname "$target")
    if [ ! -d "$target_dir" ]; then
        echo -e "${YELLOW}Creating directory: $target_dir${NC}"
        mkdir -p "$target_dir"
    fi

    # If target exists and is not a symlink, back it up
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo -e "${YELLOW}Backing up existing file: $target${NC}"
        mv "$target" "$target.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Remove existing symlink if it points to wrong location
    if [ -L "$target" ]; then
        current_link=$(readlink "$target")
        if [ "$current_link" != "$source" ]; then
            echo -e "${YELLOW}Removing outdated symlink: $target${NC}"
            rm "$target"
        fi
    fi

    # Create symlink if it doesn't exist
    if [ ! -e "$target" ]; then
        echo -e "${GREEN}Linking: $target -> $source${NC}"
        ln -s "$source" "$target"
    else
        echo -e "✓ Already linked: $target"
    fi
}

# =============================================================================
# Shell configurations
# =============================================================================
echo ""
echo "Setting up shell configurations..."

create_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/shell/.zshenv" "$HOME/.zshenv"
create_symlink "$DOTFILES_DIR/shell/.zprofile" "$HOME/.zprofile"
create_symlink "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"
create_symlink "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"
create_symlink "$DOTFILES_DIR/shell/.profile" "$HOME/.profile"
create_symlink "$DOTFILES_DIR/shell/.p10k.zsh" "$HOME/.p10k.zsh"

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

create_symlink "$DOTFILES_DIR/npm/.npmrc" "$HOME/.npmrc"

# =============================================================================
# Claude Code configurations
# =============================================================================
echo ""
echo "Setting up Claude Code configurations..."

create_symlink "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
create_symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
create_symlink "$DOTFILES_DIR/claude/statusline.ts" "$HOME/.claude/statusline.ts"
create_symlink "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
create_symlink "$DOTFILES_DIR/claude/commands" "$HOME/.claude/commands"
create_symlink "$DOTFILES_DIR/claude/agents" "$HOME/.claude/agents"

# =============================================================================
# Custom scripts
# =============================================================================
echo ""
echo "Setting up custom scripts in ~/bin..."

mkdir -p "$HOME/bin"

for script in "$DOTFILES_DIR/scripts/"*; do
    if [ -f "$script" ]; then
        script_name=$(basename "$script")
        create_symlink "$script" "$HOME/bin/$script_name"
        chmod +x "$HOME/bin/$script_name" 2>/dev/null || true
    fi
done

# =============================================================================
# Config directory
# =============================================================================
echo ""
echo "Setting up application configs..."

# Note: We'll selectively link config directories to avoid conflicts
# Only link the most important configs

if [ -d "$DOTFILES_DIR/config/gh" ]; then
    create_symlink "$DOTFILES_DIR/config/gh" "$HOME/.config/gh"
fi

if [ -d "$DOTFILES_DIR/config/raycast" ]; then
    create_symlink "$DOTFILES_DIR/config/raycast" "$HOME/.config/raycast"
fi

# For other configs, we'll just note that they're available
echo -e "${YELLOW}Note: Other application configs are available in $DOTFILES_DIR/config/${NC}"
echo -e "${YELLOW}Link them manually if needed:${NC}"
echo -e "  ln -s $DOTFILES_DIR/config/[app] ~/.config/[app]"

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
echo "1. Review templates/ directory for sensitive file configurations"
echo "2. Install Oh My Zsh (if not already installed):"
echo "   sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo ""
echo "3. Install Powerlevel10k theme:"
echo "   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
echo ""
echo "4. Install zsh plugins:"
echo "   git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
echo "   git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting"
echo ""
echo "5. Apply macOS system preferences:"
echo "   ./macos/defaults.sh"
echo ""
echo "6. Restart your terminal or run: exec zsh"
echo ""
echo "For detailed instructions, see README.md"
