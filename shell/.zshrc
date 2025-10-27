# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi



# ============================================================================
# PATH SETUP - Order matters! Most specific first
# ============================================================================

# Custom scripts
export PATH="$HOME/bin:$PATH"

# uv - Python package manager
export PATH="$HOME/.local/bin:$PATH"

# Node.js version manager (n) - HIGHEST PRIORITY for Node
export N_PREFIX="$HOME/n"
export PATH="$N_PREFIX/bin:$PATH"

# npm global packages
export PATH="$HOME/.npm-global/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/somtougeh/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# ============================================================================
# OH-MY-ZSH CONFIGURATION
# ============================================================================

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

# Enable Zsh completions
autoload -Uz compinit && compinit

# Homebrew completions (includes eza)
if type brew &>/dev/null; then
    FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
    autoload -Uz compinit
    compinit
fi

zstyle ':omz:update' mode auto
plugins=(git zsh-syntax-highlighting fast-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Enhanced completion options
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# ============================================================================
# CUSTOM FUNCTIONS
# ============================================================================

# Function to run server and install tools
function start_browser_tools() {
  echo "Starting browser tools server..."
  npx @agentdeskai/browser-tools-server@latest &
  sleep 3
  echo "Installing latest browser tools..."
  npx @agentdeskai/browser-tools-mcp@latest
}

function google() {
  gemini -p "Search google for <query>$1</query> and summarize the results"
}

# Agent guides installation function
source /Users/somtougeh/code/agent-guides/install-agent-guides.sh

# n (Node version manager) wrapper - auto-refresh hash after version change
function n() {
  # Run the actual n command
  command n "$@"
  local n_exit_code=$?
  
  # If n succeeded and arguments were provided (version change), refresh hash
  if [[ $n_exit_code -eq 0 && $# -gt 0 ]]; then
    hash -r 2>/dev/null || true
    echo "✓ Node version changed to $(node --version)"
  fi
  
  return $n_exit_code
}

# ============================================================================
# ALIASES
# ============================================================================

# Development
alias code="\"/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code\""
alias git="hub"
alias gpf="git push --force-with-lease --force-if-includes"
alias gt="gittower ."

# Navigation
alias ..="cd ../"
alias ..l="cd ../ && ll"
alias de="cd ~/Desktop"
alias d="cd ~/code"

# eza - Modern replacement for ls
alias ls="eza --icons=auto --group-directories-first"
alias ll="eza -l --icons=auto --group-directories-first --time-style=relative"
alias la="eza -a --icons=auto --group-directories-first"
alias lla="eza -la --icons=auto --group-directories-first --time-style=relative"
alias lt="eza -T --icons=auto --level=2"
alias lta="eza -Ta --icons=auto --level=2 --ignore-glob='.git'"
alias lg="eza -l --icons=auto --git --git-repos --group-directories-first"
alias lga="eza -la --icons=auto --git --git-repos --group-directories-first"
alias lsize="eza -l --icons=auto --sort=size --reverse"
alias ltime="eza -l --icons=auto --sort=modified --reverse"
alias ldot="eza -ld --icons=auto .*"

# Utilities
alias pg="echo 'Pinging Google' && ping www.google.com"
alias oz="open ~/.zshrc"
alias vz="vi ~/.zshrc"
alias sz="source ~/.zshrc"
alias rm="trash"
alias yolo="claude --dangerously-skip-permissions"
alias yoloc='codex -m gpt-5-codex -c model_reasoning_effort="high"'
alias gcauto="~/bin/gcauto"

# Package Management
alias npm-update="npx npm-check-updates --dep prod,dev --upgrade"
alias yarn-update="yarn upgrade-interactive --latest"
alias bts="npx @agentdeskai/browser-tools-server@1.2.0"
alias iag='install_agent_guides'

# ast-grep aliases
alias sg="ast-grep"  # Short alias for ast-grep
alias sgs="ast-grep scan"  # Scan with rules from config
alias sgr="ast-grep run"  # Run pattern search/rewrite
alias sgl="ast-grep scan"  # Lint with rules (scan is used for linting)
alias sgi="ast-grep run -i"  # Interactive mode
alias sgn="ast-grep new"  # Create new rule
alias sgt="ast-grep test"  # Test rules
# Helper functions for common patterns
sgp() { ast-grep run --pattern "$1" --lang "${2:-tsx}" "${3:-.}"; }  # Pattern search
sgf() { ast-grep run --pattern "$1" --lang "${2:-tsx}" . --json | jq '.'; }  # JSON output

# Python Environment (managed by uv)
alias make-python-env="uv venv"
alias go-to-python-env="source .venv/bin/activate"
alias install-pd="uv pip install -r requirements.txt"
alias uvs="uv sync"  # Sync dependencies from pyproject.toml
alias uva="uv add"  # Add a package
alias uvr="uv remove"  # Remove a package
alias uvup="uv self update"  # Update uv itself
alias python="uv run python"  # Use uv's Python
alias pip="uv pip"  # Use uv's pip replacement

# ============================================================================
# CLAUDE CONFIGURATION
# ============================================================================

export ENABLE_BACKGROUND_TASKS=1
export FORCE_AUTO_BACKGROUND_TASKS=1
export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1


# ============================================================================
# COMPLETIONS
# ============================================================================

# bun completions
[ -s "/Users/somtougeh/.bun/_bun" ] && source "/Users/somtougeh/.bun/_bun"

# ============================================================================
# ENSURE N-MANAGED NODE TAKES PRECEDENCE
# ============================================================================
# Reset command location cache to ensure correct node/npm is used
hash -r 2>/dev/null || true

# ============================================================================
# THEME CONFIGURATION
# ============================================================================

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"


typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
alias cc_usage='npx ccusage@latest'

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/somtougeh/.lmstudio/bin"
# End of LM Studio CLI section

