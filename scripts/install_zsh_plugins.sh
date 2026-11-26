#!/usr/bin/env bash
# Installs Oh My Zsh and the Zsh plugins that shell/.zshrc and work/zsh/zshrc
# load. install.sh and work/install.sh both run it, so the pins live here once.
#
# The plugins run in every shell you open. Cloning a branch means an upstream
# compromise executes here silently and forever, with no prompt. Each plugin
# is therefore pinned to a reviewed commit, and a clone that has drifted is put
# back.
#
# To update one: read the upstream diff, then bump the SHA here deliberately.
#   git -C ~/.oh-my-zsh/custom/plugins/<name> log --oneline HEAD..origin/master
set -u

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Setting up Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "✓ Oh My Zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

#              name | repo | pinned commit
ZSH_PLUGINS=(
    "fzf-tab|Aloxaf/fzf-tab|24105b15714bfec37989ed5c5b6e60f572253019"
    "zsh-autosuggestions|zsh-users/zsh-autosuggestions|85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"
    "fast-syntax-highlighting|zdharma-continuum/fast-syntax-highlighting|4672ad5dd9ad68a7effc1476d65afb7c584ce2b3"
)

for entry in "${ZSH_PLUGINS[@]}"; do
    IFS='|' read -r zp_name zp_repo zp_pin <<< "$entry"
    zp_dest="$ZSH_CUSTOM/plugins/$zp_name"

    if [ -d "$zp_dest/.git" ]; then
        zp_at="$(git -C "$zp_dest" rev-parse HEAD 2>/dev/null || echo unknown)"
        if [ "$zp_at" = "$zp_pin" ]; then
            echo "✓ $zp_name pinned at ${zp_pin:0:8}"
            continue
        fi
        echo -e "${YELLOW}$zp_name is at ${zp_at:0:8}, re-pinning to ${zp_pin:0:8}${NC}"
        git -C "$zp_dest" fetch --quiet origin 2>/dev/null || true
    else
        echo "Installing $zp_name (pinned ${zp_pin:0:8})..."
        rm -rf "$zp_dest"
        git clone --quiet "https://github.com/$zp_repo" "$zp_dest" || {
            echo -e "${RED}Could not clone $zp_repo${NC}"; continue; }
    fi

    # Detached checkout of the exact commit. If the pin is unreachable, leave
    # the plugin OUT rather than silently running whatever the branch tip is.
    if ! git -C "$zp_dest" checkout --quiet --detach "$zp_pin" 2>/dev/null; then
        echo -e "${RED}Pinned commit ${zp_pin:0:8} not found in $zp_name — removing it${NC}"
        echo -e "${YELLOW}  Verify upstream, then update the SHA in scripts/install_zsh_plugins.sh.${NC}"
        rm -rf "$zp_dest"
    fi
done
