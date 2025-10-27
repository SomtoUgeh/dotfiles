#!/bin/bash

# ============================================================================
# SHELL CONFIGURATION
# ============================================================================

export TERM=xterm-256color
export CLICOLOR=1
export LSCOLORS=Fafacxdxbxegedabagacad

# allow substitution in PS1
setopt promptsubst

# history configuration
HISTSIZE=5000
HISTFILESIZE=10000
SAVEHIST=5000
setopt EXTENDED_HISTORY
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
setopt SHARE_HISTORY      # share history across multiple zsh sessions
setopt APPEND_HISTORY     # append to history
setopt INC_APPEND_HISTORY # adds commands as they are typed, not at shell exit
setopt HIST_IGNORE_DUPS   # do not store duplications

# CDPATH configuration
CDPATH=.:$HOME:$HOME/code:$HOME/Desktop

# ============================================================================
# PATH SETUP (Order matters!)
# ============================================================================

# Homebrew
PATH="/opt/homebrew/bin:$PATH"
PATH="/usr/local/bin:$PATH"

# Custom bins
PATH="$PATH:$HOME/bin:$HOME/.bin:$HOME/.local/bin"

# node_modules (fast local bin access)
PATH="$PATH:./node_modules/.bin:../node_modules/.bin:../../node_modules/.bin:../../../node_modules/.bin:../../../../node_modules/.bin:../../../../../node_modules/.bin:../../../../../../node_modules/.bin:../../../../../../../node_modules/.bin"

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================

export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc
export SCARF_ANALYTICS=false

# Claude
export ENABLE_BACKGROUND_TASKS=1
export FORCE_AUTO_BACKGROUND_TASKS=1
export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1

# ============================================================================
# ALIASES - Editor & Navigation
# ============================================================================

alias code="\"/Applications/Cursor.app/Contents/Resources/app/bin/cursor\""
alias vz="vim ~/.zshrc"
alias cz="cursor ~/.zshrc"
alias sz="source ~/.zshrc"
alias de="cd ~/Desktop"
alias d="cd ~/code"
alias ..="cd ../"
alias ..l="cd ../ && ll"

# ============================================================================
# ALIASES - eza (Modern ls replacement)
# ============================================================================

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

# ============================================================================
# ALIASES - Git
# ============================================================================

alias git=hub
alias gs="git status"
alias gp="git pull"
alias gf="git fetch"
alias gpush="git push"
alias gpf="git push --force-with-lease --force-if-includes"
alias gd="git diff"
alias ga="git add ."

# ============================================================================
# ALIASES - Bun (Primary package manager)
# ============================================================================

alias bi="bun install"
alias bun-update-i="bun update -i"

# ============================================================================
# ALIASES - Python/uv
# ============================================================================

alias make-python-env="uv venv"
alias go-to-python-env="source .venv/bin/activate"
alias install-pd="uv pip install -r requirements.txt"
alias python="uv run python"
alias pip="uv pip"

# ============================================================================
# ALIASES - ast-grep
# ============================================================================

alias sg="ast-grep"
alias sgs="ast-grep scan"
alias sgr="ast-grep run"
alias sgl="ast-grep scan"
alias sgi="ast-grep run -i"
alias sgn="ast-grep new"
alias sgt="ast-grep test"

# ============================================================================
# ALIASES - Utilities
# ============================================================================

alias pg="echo 'Pinging Google' && ping www.google.com"
alias rm="trash"
alias showFiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder /System/Library/CoreServices/Finder.app'
alias hideFiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder /System/Library/CoreServices/Finder.app'
alias deleteDSFiles="find . -name '.DS_Store' -type f -delete"
alias flushdns="sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder"
alias dont_index_node_modules='find . -type d -name "node_modules" -exec touch "{}/.metadata_never_index" \;'

# ============================================================================
# ALIASES - AI/Dev Tools
# ============================================================================

alias yolo="claude --dangerously-skip-permissions"
alias yoloc='codex -m gpt-5-codex -c model_reasoning_effort="high"'
alias iag='install_agent_guides'

# ============================================================================
# FUNCTIONS
# ============================================================================

# Cursor shortcut
c() { cursor ${@:-.}; }

# Git commit
gc() { git commit -m "$@"; }

# Git diff
dif() { git diff --color --no-index "$1" "$2" | diff-so-fancy; }
cdiff() { cursor --diff "$1" "$2"; }

# ast-grep helpers
sgp() { ast-grep run --pattern "$1" --lang "${2:-tsx}" "${3:-.}"; }
sgf() { ast-grep run --pattern "$1" --lang "${2:-tsx}" . --json | jq '.'; }

# Directory helpers
mg() { mkdir "$@" && cd "$@" || exit; }
cdl() { cd "$@" && ll; }

# npm helper
npm-latest() { npm info "$1" | grep latest; }

# Kill process on port
killport() { lsof -i tcp:"$*" | awk 'NR!=1 {print $2}' | xargs kill -9; }

# Quit macOS app
quit() {
  if [ -z "$1" ]; then
    echo "Usage: quit appname"
  else
    for appname in $1; do
      osascript -e 'quit app "'$appname'"'
    done
  fi
}

# Convert video to GIF
gif() {
  ffmpeg -i "$1" -vf "fps=25,scale=iw/2:ih/2:flags=lanczos,palettegen" -y "/tmp/palette.png"
  ffmpeg -i "$1" -i "/tmp/palette.png" -lavfi "fps=25,scale=iw/2:ih/2:flags=lanczos [x]; [x][1:v] paletteuse" -f image2pipe -vcodec ppm - | convert -delay 4 -layers Optimize -loop 0 - "${1%.*}.gif"
}

# ============================================================================
# COMPLETIONS
# ============================================================================

autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ============================================================================
# TOOL INTEGRATIONS
# ============================================================================

# fnm (Fast Node Manager)
FNM_PATH="/opt/homebrew/opt/fnm/bin"
if [ -d "$FNM_PATH" ]; then
  eval "$(fnm env)"
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# uv - Python package manager
export PATH="$HOME/.local/bin:$PATH"

# PostgreSQL
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# OrbStack
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# Agent guides
[ -f "$HOME/code/agent-guides/install-agent-guides.sh" ] && source "$HOME/code/agent-guides/install-agent-guides.sh"

# ============================================================================
# PRIVATE CONFIG
# ============================================================================

[ -f ~/.zshrc.private ] && source ~/.zshrc.private

# ============================================================================
# PROMPT INITIALIZATION (Keep at end)
# ============================================================================

eval "$(starship init zsh)"
