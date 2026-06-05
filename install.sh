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

    # Handle an existing symlink (use -L so a *broken* link is still detected;
    # -e follows the link and reports false when the target is missing, which is
    # exactly how a stale link slips through and later makes `ln` abort the run).
    if [ -L "$target" ]; then
        current_link=$(readlink "$target")
        if [ "$current_link" = "$source" ]; then
            echo -e "✓ Already linked: $target"
            return
        fi
        echo -e "${YELLOW}Removing outdated symlink: $target${NC}"
        rm "$target"
    fi

    # Create symlink. -f guards against any residual path component (e.g. a
    # racing process) so a stale entry can never abort the installer.
    echo -e "${GREEN}Linking: $target -> $source${NC}"
    ln -sf "$source" "$target"
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
    # Homebrew needs sudo to create its prefix. In NONINTERACTIVE mode it
    # REFUSES to prompt for a password — it requires passwordless sudo, which a
    # normal machine doesn't have. So only force NONINTERACTIVE when there is no
    # TTY *and* sudo already works without a password (e.g. CI). With a real
    # terminal, run interactively so Homebrew can prompt for the password once.
    if [ -t 0 ]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    elif sudo -n true 2>/dev/null; then
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo -e "${RED}Cannot install Homebrew: no TTY for a password prompt and passwordless sudo is unavailable.${NC}"
        echo -e "${YELLOW}Run this once in a real terminal window, then re-run ./install.sh:${NC}"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo -e "${YELLOW}(Do NOT use sudo, and do NOT run it via Claude Code’s ! prefix — both lack a TTY.)${NC}"
        exit 1
    fi
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
# JavaScript runtimes (bun, pnpm) — official installers, not Homebrew
# =============================================================================
# shell/.zshrc already wires both (BUN_INSTALL=~/.bun, PNPM_HOME=~/Library/pnpm).
# Both installers try to append PATH blocks to the shell rc, and since ~/.zshrc
# is a symlink to the tracked dotfiles file, that would pollute it with
# non-portable hardcoded paths. We revert any such edits afterward — but only if
# the shell configs started clean, so we never clobber real local changes.
echo ""
echo "Installing JavaScript runtimes (bun, pnpm)..."

shell_was_clean=0
git -C "$DOTFILES_DIR" diff --quiet -- shell/ 2>/dev/null && shell_was_clean=1

if command -v bun &> /dev/null || [ -x "$HOME/.bun/bin/bun" ]; then
    echo "✓ bun already installed"
else
    echo "Installing bun..."
    curl -fsSL https://bun.sh/install | bash || \
        echo -e "${YELLOW}bun install failed (skipped).${NC}"
fi

if command -v pnpm &> /dev/null || [ -x "$HOME/Library/pnpm/bin/pnpm" ]; then
    echo "✓ pnpm already installed"
else
    echo "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh - || \
        echo -e "${YELLOW}pnpm install failed (skipped).${NC}"
fi

# Discard PATH blocks the installers appended to the tracked, symlinked shell
# configs (only when they started clean — see note above).
if [ "$shell_was_clean" = "1" ] && ! git -C "$DOTFILES_DIR" diff --quiet -- shell/ 2>/dev/null; then
    echo -e "${YELLOW}Reverting installer edits to tracked shell configs (already wired in dotfiles).${NC}"
    git -C "$DOTFILES_DIR" checkout -- shell/
fi

# =============================================================================
# Node via fnm (latest) — keep fnm the only Node on the machine
# =============================================================================
# fnm is installed via Homebrew, but with no default version every shell falls
# back to a system/brew Node. Install the latest and pin it as the default.
if command -v fnm &> /dev/null; then
    echo ""
    echo "Setting up Node via fnm..."

    if fnm ls 2>/dev/null | grep -qE 'v[0-9]+\.'; then
        echo "✓ fnm already manages a Node version"
    else
        latest_node="$(fnm ls-remote --latest 2>/dev/null | tail -1)"
        if [ -n "$latest_node" ]; then
            echo "Installing latest Node ($latest_node)..."
            fnm install "$latest_node" && fnm default "$latest_node" || \
                echo -e "${YELLOW}fnm Node setup failed (skipped).${NC}"
        else
            echo -e "${YELLOW}Could not determine latest Node from fnm (skipped).${NC}"
        fi
    fi

    # Load fnm's Node so npm is on PATH for the global install below.
    eval "$(fnm env)" 2>/dev/null || true
    fnm use default 2>/dev/null || true

    # neonctl on fnm's Node (see Brewfile note: the brew formula bundles a second
    # Node, which would defeat fnm being the only Node).
    if command -v npm &> /dev/null; then
        if npm ls -g --depth=0 neonctl &> /dev/null; then
            echo "✓ neonctl already installed (npm global)"
        else
            echo "Installing neonctl (npm global on fnm Node)..."
            npm install -g neonctl || echo -e "${YELLOW}neonctl install failed (skipped).${NC}"
        fi
    fi
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
create_symlink "$AGENTS_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
create_symlink "$AGENTS_DIR/shared/ETHOS.md" "$HOME/.claude/ETHOS.md"
# settings.json is SYMLINKED, not rendered. Claude resolves the link and writes
# through it (atomic temp+rename at the real path), so the repo copy always
# reflects live config and never drifts. It uses ${HOME}-relative paths, so no
# per-host rendering is needed. Its enabledPlugins + extraKnownMarketplaces are
# the single source of truth for plugins (the installed_plugins.json /
# known_marketplaces.json caches are derived and are no longer tracked).
create_symlink "$AGENTS_DIR/claude/settings.json" "$HOME/.claude/settings.json"
# NOTE: mcp.json is NOT symlinked. Claude Code does not read ~/.claude/mcp.json;
# it loads MCP servers from ~/.claude.json (user scope) or a project .mcp.json.
# agents/claude/mcp.json is the declarative inventory, registered via the CLI in
# the "Claude MCP servers" block below. Remove any stale dead symlink from a prior install.
rm -f "$HOME/.claude/mcp.json"
create_symlink "$AGENTS_DIR/claude/commands" "$HOME/.claude/commands"
create_symlink "$AGENTS_DIR/claude/agents" "$HOME/.claude/agents"
create_symlink "$AGENTS_DIR/skills" "$HOME/.claude/skills"
create_symlink "$AGENTS_DIR/shared/hooks/git_guard.py" "$HOME/.claude/hooks/git_guard.py"
create_symlink "$AGENTS_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
create_symlink "$AGENTS_DIR/claude/file-suggestion.sh" "$HOME/.claude/file-suggestion.sh"
chmod +x "$HOME/.claude/hooks/git_guard.py" "$HOME/.claude/statusline.sh" "$HOME/.claude/file-suggestion.sh" 2>/dev/null || true

# Codex
mkdir -p "$HOME/.codex"
create_symlink "$AGENTS_DIR/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
create_symlink "$AGENTS_DIR/shared/ETHOS.md" "$HOME/.codex/ETHOS.md"
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
create_symlink "$AGENTS_DIR/shared/ETHOS.md" "$HOME/.config/opencode/ETHOS.md"
create_symlink "$AGENTS_DIR/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
create_symlink "$AGENTS_DIR/opencode/agents" "$HOME/.config/opencode/agents"
create_symlink "$AGENTS_DIR/opencode/commands" "$HOME/.config/opencode/commands"
# Symlink the whole plugins dir. Do NOT `mkdir -p` this path first: if it is
# already a stale/broken symlink (e.g. dotfiles repo moved), mkdir follows the
# dangling link, fails, and `set -e` aborts the entire installer. create_symlink
# clears a broken link and recreates it correctly on its own.
create_symlink "$AGENTS_DIR/opencode/plugins" "$HOME/.config/opencode/plugins"

# Claude plugins: declared once in the symlinked settings.json (enabledPlugins +
# extraKnownMarketplaces) — the single source of truth. Claude also syncs these
# on launch, but install them explicitly so a fresh machine is ready without a
# first-run round-trip. enabledPlugins keys are already in "name@marketplace" form.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if command -v claude &> /dev/null && [ -f "$CLAUDE_SETTINGS" ]; then
    echo "Installing Claude Code plugins from settings.json..."
    # Register non-default (GitHub) marketplaces first.
    python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for m in (d.get("extraKnownMarketplaces") or {}).values():
    s=m.get("source",{})
    if s.get("source")=="github" and s.get("repo"): print(s["repo"])' "$CLAUDE_SETTINGS" | while IFS= read -r repo; do
        if [ -n "$repo" ]; then claude plugins marketplace add "$repo" 2>/dev/null || true; fi
    done
    # Install every enabled plugin.
    python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k,v in (d.get("enabledPlugins") or {}).items():
    if v: print(k)' "$CLAUDE_SETTINGS" | while IFS= read -r plugin; do
        if [ -n "$plugin" ]; then
            echo "  Installing plugin: $plugin"
            claude plugins install "$plugin" 2>/dev/null || true
        fi
    done
elif ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}Claude CLI not found. Skipping plugin install (Claude syncs enabledPlugins from settings.json on first launch).${NC}"
fi

# Claude MCP servers: declared in agents/claude/mcp.json (the inventory). Claude
# Code does NOT read ~/.claude/mcp.json, so register each remote server at user
# scope via the CLI — idempotent (skips if already present), available in every
# session from any directory.
CLAUDE_MCP="$AGENTS_DIR/claude/mcp.json"
if command -v claude &> /dev/null && [ -f "$CLAUDE_MCP" ]; then
    echo "Registering Claude MCP servers from mcp.json (user scope)..."
    python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for name,cfg in (d.get("mcpServers") or {}).items():
    t=cfg.get("type","stdio"); url=cfg.get("url","")
    if t in ("http","sse") and url: print(f"{name}\t{t}\t{url}")' "$CLAUDE_MCP" | while IFS=$'\t' read -r name transport url; do
        if [ -n "$name" ] && ! claude mcp get "$name" &> /dev/null; then
            echo "  Adding MCP server: $name ($transport)"
            claude mcp add --transport "$transport" --scope user "$name" "$url" 2>/dev/null || true
        fi
    done
fi

# =============================================================================
# cmux terminal
# =============================================================================
# cmux.json is a user-authored override layer (JSONC). cmux reads it but never
# writes back to it (in-app changes go to its own Settings store), so symlinking
# the tracked copy is safe and never drifts.
echo ""
echo "Setting up cmux configuration..."

mkdir -p "$HOME/.config/cmux"
create_symlink "$DOTFILES_DIR/config/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"

# cmux's embedded terminal is Ghostty-backed and reads ~/.config/ghostty/config
# for font, spacing, and rendering. (The standalone Ghostty app is no longer used.)
mkdir -p "$HOME/.config/ghostty"
create_symlink "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"

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
# mkdir -p (don't guard on the dir existing): on a fresh machine VSCode hasn't
# launched yet so the User dir is absent, and the old `if [ -d ]` guard skipped
# linking entirely — leaving VSCode on empty defaults. Match the Zed/Ghostty blocks.
if [ -d "/Applications/Visual Studio Code.app" ]; then
    echo "Setting up VSCode configuration..."
    mkdir -p "$VSCODE_CONFIG_DIR"
    create_symlink "$DOTFILES_DIR/config/vscode/vscode-settings.json" "$VSCODE_CONFIG_DIR/settings.json"
    create_symlink "$DOTFILES_DIR/config/vscode/vscode-keybindings.json" "$VSCODE_CONFIG_DIR/keybindings.json"

    # Install extensions from the manifest (VSCode has no auto-install like Zed,
    # so themes/icons would silently fall back without this). Needs the `code` CLI.
    if [ -f "$DOTFILES_DIR/config/vscode/extensions.txt" ] && command -v code &> /dev/null; then
        echo "Installing VSCode extensions..."
        while IFS= read -r ext || [ -n "$ext" ]; do
            [[ "$ext" =~ ^#.*$ || -z "$ext" ]] && continue
            echo "  Installing extension: $ext"
            code --install-extension "$ext" --force &> /dev/null || echo -e "${YELLOW}  Failed: $ext${NC}"
        done < "$DOTFILES_DIR/config/vscode/extensions.txt"
    fi
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
        # Non-fatal: a cancelled sudo prompt must not abort the whole install.
        sudo chown -R "$(whoami)" "$BREW_PREFIX" || \
            echo -e "${YELLOW}Could not fix Homebrew permissions (skipped). brew bundle may fail.${NC}"
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
# Touch ID for sudo (optional — modifies /etc/pam.d/sudo_local)
# =============================================================================
echo ""
if [ -f /etc/pam.d/sudo_local ] && grep -q '^auth.*pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null; then
    echo "✓ Touch ID for sudo already enabled"
elif [ -f "$DOTFILES_DIR/scripts/enable_touchid_sudo.sh" ]; then
    # Only prompt when attached to a terminal. Without a TTY, `read` returns
    # non-zero on EOF and would abort the whole script under `set -e`.
    if [ -t 0 ] && read -r -p "Enable Touch ID for sudo? (needs your password once) [y/N] " enable_touchid; then
        :
    else
        enable_touchid=""
        [ -t 0 ] || echo "  Non-interactive: skipping Touch ID setup. Run later with: enable_touchid_sudo.sh"
    fi
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
