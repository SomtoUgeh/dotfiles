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

# Render a machine-local copy of a template file.
render_agent_file() {
    local source="$1"
    local target="$2"

    local target_dir
    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"

    if [ -L "$target" ]; then
        rm "$target"
    fi

    sed \
        -e "s#\\\${HOME}/code/dotfiles#${DOTFILES_DIR}#g" \
        -e "s#/Users/somto#${HOME}#g" \
        "$source" > "$target"
}

# =============================================================================
# Homebrew (bootstrap — everything below may depend on it)
# =============================================================================
echo ""
echo "Setting up Homebrew..."

if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Put brew on PATH for the rest of this script (Apple Silicon + Intel)
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "✓ Homebrew already installed"
fi

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
# Claude Code CLI
# =============================================================================
echo ""
echo "Installing Claude Code CLI..."

if command -v claude &> /dev/null; then
    echo "✓ Claude Code already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# =============================================================================
# Agent configurations
# =============================================================================
echo ""
echo "Setting up agent configurations..."

AGENTS_DIR="$DOTFILES_DIR/agents"

# Shared skills live at the neutral path. Codex and OpenCode discover
# ~/.agents/skills directly; Claude also gets its native ~/.claude/skills link.
# Do not replace ~/.codex/skills: Codex may keep local-only skills there.
mkdir -p "$HOME/.agents"
create_symlink "$AGENTS_DIR/skills" "$HOME/.agents/skills"

# Claude Code
mkdir -p "$HOME/.claude/hooks"
mkdir -p "$HOME/.claude/plugins"
create_symlink "$AGENTS_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
create_symlink "$AGENTS_DIR/shared/ETHOS.md" "$HOME/.claude/ETHOS.md"
render_agent_file "$AGENTS_DIR/claude/settings.json" "$HOME/.claude/settings.json"
chmod 600 "$HOME/.claude/settings.json"
create_symlink "$AGENTS_DIR/claude/mcp.json" "$HOME/.claude/mcp.json"
create_symlink "$AGENTS_DIR/claude/commands" "$HOME/.claude/commands"
create_symlink "$AGENTS_DIR/claude/agents" "$HOME/.claude/agents"
create_symlink "$AGENTS_DIR/skills" "$HOME/.claude/skills"
create_symlink "$AGENTS_DIR/shared/hooks/git_guard.py" "$HOME/.claude/hooks/git_guard.py"
create_symlink "$AGENTS_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
create_symlink "$AGENTS_DIR/claude/file-suggestion.sh" "$HOME/.claude/file-suggestion.sh"
chmod +x "$HOME/.claude/hooks/git_guard.py" "$HOME/.claude/statusline.sh" "$HOME/.claude/file-suggestion.sh" 2>/dev/null || true

if [ -d "$AGENTS_DIR/claude/plugins" ]; then
    for plugin_file in "$AGENTS_DIR/claude/plugins/"*.json; do
        if [ -f "$plugin_file" ]; then
            plugin_name=$(basename "$plugin_file")
            local_plugin_file="$HOME/.claude/plugins/$plugin_name"
            render_agent_file "$plugin_file" "$local_plugin_file"
            chmod 600 "$local_plugin_file"
            echo -e "${GREEN}✓ Rebuilt local Claude plugin metadata: $local_plugin_file${NC}"
        fi
    done
fi

# Codex
mkdir -p "$HOME/.codex"
create_symlink "$AGENTS_DIR/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
if [ -f "$AGENTS_DIR/codex/config.toml" ]; then
    render_agent_file "$AGENTS_DIR/codex/config.toml" "$HOME/.codex/config.toml"
    chmod 600 "$HOME/.codex/config.toml"
    echo -e "${GREEN}✓ Rebuilt host-local Codex config: $HOME/.codex/config.toml${NC}"
fi
if [ -f "$AGENTS_DIR/codex/hooks.json" ]; then
    render_agent_file "$AGENTS_DIR/codex/hooks.json" "$HOME/.codex/hooks.json"
    chmod 600 "$HOME/.codex/hooks.json"
    echo -e "${GREEN}✓ Rebuilt host-local Codex hooks: $HOME/.codex/hooks.json${NC}"
fi
create_symlink "$AGENTS_DIR/codex/agents" "$HOME/.codex/agents"

# OpenCode
mkdir -p "$HOME/.config/opencode"
create_symlink "$AGENTS_DIR/opencode/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
create_symlink "$AGENTS_DIR/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
create_symlink "$AGENTS_DIR/opencode/agents" "$HOME/.config/opencode/agents"
create_symlink "$AGENTS_DIR/opencode/commands" "$HOME/.config/opencode/commands"
mkdir -p "$HOME/.config/opencode/plugins"
create_symlink "$AGENTS_DIR/opencode/plugins" "$HOME/.config/opencode/plugins"

# Claude plugins (install if claude CLI available)
if [ -f "$AGENTS_DIR/claude/plugins.txt" ] && command -v claude &> /dev/null; then
    echo "Installing Claude Code plugins..."
    while IFS= read -r plugin || [ -n "$plugin" ]; do
        # Skip comments and empty lines
        [[ "$plugin" =~ ^#.*$ || -z "$plugin" ]] && continue
        echo "  Installing plugin: $plugin"
        claude plugins install "${plugin}@claude-plugins-official" 2>/dev/null || true
    done < "$AGENTS_DIR/claude/plugins.txt"
else
    if [ -f "$AGENTS_DIR/claude/plugins.txt" ]; then
        echo -e "${YELLOW}Claude CLI not found. Skipping plugin installation.${NC}"
        echo "  Run manually after installing Claude: claude plugins install <plugin>@claude-plugins-official"
    fi
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
# VSCode
# =============================================================================
echo ""

VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
if [ -d "$VSCODE_CONFIG_DIR" ]; then
    echo "Setting up VSCode configuration..."
    create_symlink "$DOTFILES_DIR/config/vscode/vscode-settings.json" "$VSCODE_CONFIG_DIR/settings.json"
    create_symlink "$DOTFILES_DIR/config/vscode/vscode-keybindings.json" "$VSCODE_CONFIG_DIR/keybindings.json"
fi

# =============================================================================
# Starship prompt
# =============================================================================
echo ""
echo "Setting up Starship configuration..."

mkdir -p "$HOME/.config"
create_symlink "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"

# =============================================================================
# GitHub CLI
# =============================================================================
echo ""
echo "Setting up GitHub CLI configuration..."

mkdir -p "$HOME/.config/gh"
create_symlink "$DOTFILES_DIR/config/gh/config.yml" "$HOME/.config/gh/config.yml"

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
    BREW_PREFIX="$(brew --prefix)"
    if [ ! -w "$BREW_PREFIX" ]; then
        echo -e "${YELLOW}Fixing Homebrew permissions...${NC}"
        sudo chown -R "$(whoami)" "$BREW_PREFIX"
    fi
    echo "Running brew bundle install..."
    cd "$DOTFILES_DIR"
    # Non-fatal: one failing cask (delisted app, network blip) must not abort
    # the rest of the install. Failures are summarized below.
    if ! brew bundle install; then
        echo -e "${YELLOW}Some brew packages failed to install. Review above and re-run 'brew bundle install' to retry.${NC}"
    fi
else
    echo -e "${RED}Homebrew not found. Please install Homebrew first:${NC}"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

# =============================================================================
# Claude session sync (daily cron → qmd)
# =============================================================================
echo ""
echo "Setting up Claude session sync..."

if [ -f "$DOTFILES_DIR/scripts/setup-session-sync.sh" ]; then
    chmod +x "$DOTFILES_DIR/scripts/setup-session-sync.sh"
    chmod +x "$DOTFILES_DIR/scripts/scheduled-session-sync.sh"
    chmod +x "$DOTFILES_DIR/scripts/sync-sessions-to-qmd.sh"
    if command -v qmd &> /dev/null; then
        bash "$DOTFILES_DIR/scripts/setup-session-sync.sh"
    else
        echo -e "${YELLOW}qmd not found. Skipping session sync setup.${NC}"
        echo "  Install qmd, then run: scripts/setup-session-sync.sh"
    fi
fi

# =============================================================================
# Touch ID for sudo (optional — modifies /etc/pam.d/sudo_local)
# =============================================================================
echo ""
if [ -f /etc/pam.d/sudo_local ] && grep -q '^auth.*pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null; then
    echo "✓ Touch ID for sudo already enabled"
elif [ -f "$DOTFILES_DIR/scripts/enable_touchid_sudo.sh" ]; then
    read -r -p "Enable Touch ID for sudo? (needs your password once) [y/N] " enable_touchid
    if [[ "$enable_touchid" =~ ^[Yy]$ ]]; then
        bash "$DOTFILES_DIR/scripts/enable_touchid_sudo.sh"
    else
        echo "  Skipped. Run later with: enable_touchid_sudo.sh"
    fi
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
