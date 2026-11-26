#!/usr/bin/env bash
#
# Work Mac installer. Sets up the same shell, editors and apps as the personal
# Mac, without the personal identity or infrastructure. See work/README.md.
#
#   work/install.sh               full install (Homebrew bundle, Node, links)
#   work/install.sh --links-only  links and rendered files only; no downloads
#
# Safe to run again. It never pushes, never signs in to anything, and writes no
# company names, hosts or emails into this public repository.
#
# Left out on purpose: the personal Executor gateway, boat VMs, the gh-personal
# account, Codex/OpenCode/Grok config, Tailscale, and the personal Brewfile.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$WORK_DIR/.." && pwd)"

LINKS_ONLY=0
case "${1:-}" in
    "") ;;
    --links-only) LINKS_ONLY=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

# Shows a path with ~ for $HOME. Pattern substitution expands a ~ in bash 5.
short() { case "$1" in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
hdr()  { echo ""; echo "== $1"; }

create_symlink() {
    local source="$1" target="$2"
    mkdir -p "$(dirname "$target")"
    if [ -L "$target" ]; then
        if [ "$(readlink "$target")" = "$source" ]; then
            ok "linked $(short "$target")"
            return
        fi
        rm "$target"
    elif [ -e "$target" ]; then
        local backup
        backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$target" "$backup"
        warn "backed up $(short "$target") to $(short "$backup")"
    fi
    ln -s "$source" "$target"
    ok "linked $(short "$target") -> ${source/#$DOTFILES_DIR/<dotfiles>}"
}

# Writes generated content to a real file. A file without the marker belongs to
# the user and is left alone.
MARKER="Rendered by work/install.sh"
render_file() {
    local target="$1" content="$2"
    mkdir -p "$(dirname "$target")"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ] && ! grep -q "$MARKER" "$target"; then
        warn "kept your own $(short "$target") (no '$MARKER' line)"
        return
    fi
    if [ -f "$target" ] && [ "$(cat "$target")" = "$content" ]; then
        ok "current $(short "$target")"
        return
    fi
    printf '%s\n' "$content" > "$target"
    ok "wrote $(short "$target")"
}

echo "Work Mac setup from $DOTFILES_DIR"
[ "$LINKS_ONLY" = 1 ] && echo "(--links-only: no downloads)"

[ "$(uname -s)" = Darwin ] || { echo -e "${RED}This installer is for macOS.${NC}" >&2; exit 1; }

if [ -e "$HOME/.gitconfig-personal" ]; then
    warn "~/.gitconfig-personal exists. git/.gitconfig applies it in ~/code/personal."
    warn "Delete it unless you mean to commit as your personal identity on this Mac."
fi

mkdir -p "$HOME/code/work" "$HOME/bin" "$HOME/.config" "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# =============================================================================
# Homebrew
# =============================================================================
if [ "$LINKS_ONLY" = 0 ]; then
    hdr "Homebrew"
    if ! command -v brew >/dev/null 2>&1; then
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            echo -e "${RED}Homebrew is not installed.${NC} Install it in a real terminal (it asks for your password):"
            echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            exit 1
        fi
    fi
    # Non-fatal: one failing cask must not stop the rest. Some casks need sudo,
    # which fails without a terminal; rerun the bundle in a terminal to finish.
    if brew bundle install --file="$WORK_DIR/Brewfile"; then
        ok "work Brewfile installed"
    else
        warn "some packages failed. Rerun in a terminal: brew bundle install --file=work/Brewfile"
    fi

    hdr "Oh My Zsh"
    bash "$DOTFILES_DIR/scripts/install_zsh_plugins.sh"
fi

# =============================================================================
# Shell and git
# =============================================================================
hdr "Shell"
create_symlink "$WORK_DIR/zsh/zshrc" "$HOME/.zshrc"
create_symlink "$WORK_DIR/zsh/zshenv" "$HOME/.zshenv"
create_symlink "$DOTFILES_DIR/shell/.zprofile" "$HOME/.zprofile"
if [ ! -e "$HOME/.zshrc.private" ]; then
    cp "$WORK_DIR/zshrc-private.template" "$HOME/.zshrc.private"
    chmod 600 "$HOME/.zshrc.private"
    ok "wrote ~/.zshrc.private from the template (add company values there)"
fi

hdr "Git"
# Shared settings as the XDG global file, work identity rules as ~/.gitconfig.
create_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.config/git/config"
create_symlink "$WORK_DIR/git/gitconfig" "$HOME/.gitconfig"
create_symlink "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"
if [ ! -e "$HOME/.gitconfig.local" ]; then
    cp "$DOTFILES_DIR/templates/gitconfig-local.template" "$HOME/.gitconfig.local"
    chmod 600 "$HOME/.gitconfig.local"
    ok "wrote ~/.gitconfig.local (your name only)"
fi

# =============================================================================
# Terminal, prompt and editors
# =============================================================================
hdr "Terminal and prompt"
create_symlink "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"
create_symlink "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
create_symlink "$DOTFILES_DIR/config/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"

hdr "Zed"
# A copy, not a link: the personal file lists the personal VMs under
# ssh_connections, and Zed's own edits should stay on this Mac.
zed_settings="$(awk '
    /^  "ssh_connections": \[/ { skip = 1; next }
    skip && /^  \],?$/        { skip = 0; next }
    !skip
' "$DOTFILES_DIR/config/zed/settings.json")"
if [[ "$zed_settings" == *'"ssh_connections"'* ]]; then
    echo -e "${RED}Could not remove ssh_connections from the Zed settings; Zed settings not written.${NC}" >&2
    exit 1
fi
render_file "$HOME/.config/zed/settings.json" "// $MARKER from config/zed/settings.json, without the personal SSH hosts.
// Rerun work/install.sh to refresh it. Zed edits here stay on this Mac.
$zed_settings"
create_symlink "$DOTFILES_DIR/config/zed/keymap.json" "$HOME/.config/zed/keymap.json"

hdr "VS Code"
vscode_user="$HOME/Library/Application Support/Code/User"
create_symlink "$DOTFILES_DIR/config/vscode/vscode-settings.json" "$vscode_user/settings.json"
create_symlink "$DOTFILES_DIR/config/vscode/vscode-keybindings.json" "$vscode_user/keybindings.json"
code_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
if [ -x "$code_cli" ]; then
    create_symlink "$code_cli" "$HOME/bin/code"
fi
if [ "$LINKS_ONLY" = 0 ] && [ -x "$code_cli" ]; then
    while IFS= read -r ext || [ -n "$ext" ]; do
        case "$ext" in ''|'#'*) continue ;; esac
        "$code_cli" --install-extension "$ext" --force >/dev/null 2>&1 || warn "extension failed: $ext"
    done < "$DOTFILES_DIR/config/vscode/extensions.txt"
    ok "VS Code extensions processed"
fi

# =============================================================================
# Node (LTS) via fnm
# =============================================================================
if [ "$LINKS_ONLY" = 0 ] && command -v fnm >/dev/null 2>&1; then
    hdr "Node"
    if [[ "$(fnm ls 2>/dev/null)" =~ v[0-9]+\. ]]; then
        ok "fnm already manages a Node version"
    else
        # LTS, not the newest release: work repositories target LTS. fnm still
        # switches per project from .nvmrc / .node-version.
        lts="$(fnm ls-remote --lts 2>/dev/null | awk 'END { print $1 }')"
        if [ -n "$lts" ] && fnm install "$lts" && fnm default "$lts"; then
            ok "Node $lts installed as the default"
        else
            warn "could not install the Node LTS with fnm"
        fi
    fi
fi

# =============================================================================
# Claude Code
# =============================================================================
hdr "Claude Code"
if [ "$LINKS_ONLY" = 0 ]; then
    if command -v claude >/dev/null 2>&1; then
        ok "Claude Code CLI already installed"
    else
        curl -fsSL https://claude.ai/install.sh | bash || warn "Claude Code install failed"
    fi
fi
mkdir -p "$HOME/.claude/hooks"
# The shared instructions, without the section that routes every MCP call
# through the personal Executor gateway.
claude_md="<!-- $MARKER from agents/shared/AGENTS.md, without the personal MCP section. Rerun to refresh. -->
$(awk '
    /^## Shared MCP access/ { skip = 1; next }
    skip && /^## /          { skip = 0 }
    !skip
' "$DOTFILES_DIR/agents/shared/AGENTS.md")"
render_file "$HOME/.claude/CLAUDE.md" "$claude_md"
create_symlink "$DOTFILES_DIR/agents/shared/ETHOS.md" "$HOME/.claude/ETHOS.md"
create_symlink "$DOTFILES_DIR/agents/claude/output-styles" "$HOME/.claude/output-styles"
create_symlink "$DOTFILES_DIR/agents/claude/agents" "$HOME/.claude/agents"
create_symlink "$DOTFILES_DIR/agents/claude/statusline.sh" "$HOME/.claude/statusline.sh"
create_symlink "$DOTFILES_DIR/agents/shared/hooks/git_guard.py" "$HOME/.claude/hooks/git_guard.py"
# A copy, so Claude's own writes stay on this Mac. Never overwritten.
if [ -e "$HOME/.claude/settings.json" ]; then
    ok "kept existing ~/.claude/settings.json"
else
    cp "$WORK_DIR/claude/settings.json" "$HOME/.claude/settings.json"
    ok "wrote ~/.claude/settings.json"
fi

# =============================================================================
# Commands in ~/bin
# =============================================================================
hdr "~/bin"
for script_name in scan_repo.sh enable_touchid_sudo.sh; do
    create_symlink "$DOTFILES_DIR/scripts/$script_name" "$HOME/bin/$script_name"
done
create_symlink "$WORK_DIR/setup_gitlab.sh" "$HOME/bin/setup_gitlab.sh"

# =============================================================================
# Next steps
# =============================================================================
hdr "Done"
cat <<'EOF'
Next (see work/README.md):
  1. work/setup_gitlab.sh --host <gitlab-host> --email <work-email>
  2. Sign in to the apps (Raycast, Spark, Spotify, Slack) and set Hidden Bar.
  3. In a real terminal: ./macos/defaults.sh, then enable_touchid_sudo.sh
  4. exec zsh
EOF
