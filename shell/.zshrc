#!/bin/zsh

# ============================================================================
# OH MY ZSH SETUP
# ============================================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # Using Starship instead

plugins=(fzf-tab zsh-autosuggestions fast-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# ============================================================================
# SHELL CONFIGURATION
# ============================================================================

export TERM=xterm-256color
export CLICOLOR=1
export LSCOLORS=Fafacxdxbxegedabagacad

setopt promptsubst

# History
HISTSIZE=5000
HISTFILESIZE=10000
SAVEHIST=5000
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS

# CDPATH configuration
CDPATH=.:$HOME:$HOME/code:$HOME/Desktop

# ============================================================================
# PATH SETUP
# ============================================================================

# Homebrew
PATH="/opt/homebrew/bin:$PATH"
PATH="/usr/local/bin:$PATH"

# Custom bins
PATH="$PATH:$HOME/bin:$HOME/.bin:$HOME/.local/bin"

# node_modules (fast local bin access)
PATH="$PATH:./node_modules/.bin:../node_modules/.bin:../../node_modules/.bin:../../../node_modules/.bin:../../../../node_modules/.bin:../../../../../node_modules/.bin:../../../../../../node_modules/.bin:../../../../../../../node_modules/.bin"

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
# COMPLETIONS
# ============================================================================

autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ============================================================================
# ALIASES
# ============================================================================

# Editor & Navigation
alias vz="vim ~/.zshrc"
alias zz="z ~/.zshrc"
alias sz="source ~/.zshrc"
alias de="cd ~/Desktop"
alias d="cd ~/code"
alias ..="cd ../"
alias ..l="cd ../ && ll"

# eza (Modern ls)
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

# Git
alias gs="git status"
alias gp="git pull"
alias gf="git fetch"
alias gpush="git push"
alias gpf="git push --force-with-lease --force-if-includes"
alias gd="git diff"
alias ga="git add ."

# Bun
alias bi="bun install"
alias bun-update-i="bun update -i"

# Python/uv
alias make-python-env="uv venv"
alias go-to-python-env="source .venv/bin/activate"
alias install-pd="uv pip install -r requirements.txt"
alias python="uv run python"
alias pip="uv pip"

# ast-grep
alias sg="ast-grep"
alias sgs="ast-grep scan"
alias sgr="ast-grep run"
alias sgl="ast-grep scan"
alias sgi="ast-grep run -i"
alias sgn="ast-grep new"
alias sgt="ast-grep test"

# Utilities
alias pg="echo 'Pinging Google' && ping www.google.com"
alias rm="trash"
alias showFiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder /System/Library/CoreServices/Finder.app'
alias hideFiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder /System/Library/CoreServices/Finder.app'
alias deleteDSFiles="find . -name '.DS_Store' -type f -delete"
alias flushdns="sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder"
alias dont_index_node_modules='find . -type d -name "node_modules" -exec touch "{}/.metadata_never_index" \;'
alias cat="bat"

# AI/Dev Tools
alias yolo="claude --dangerously-skip-permissions"

# ============================================================================
# FUNCTIONS
# ============================================================================

# Zed shortcut
z() {
  /Applications/Zed.app/Contents/MacOS/cli ${@:-.} > /dev/null 2>&1 &!
}

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

# Git alias (after functions to avoid parse errors)
alias git=hub

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
# PRIVATE CONFIG
# ============================================================================

[ -f ~/.zshrc.private ] && source ~/.zshrc.private

# ============================================================================
# PROMPT (Keep at end)
# ============================================================================

export STARSHIP_CONFIG="$HOME/code/dotfiles/config/starship/starship.toml"
eval "$(starship init zsh)"

# bun completions
[ -s "/Users/swissblock/.bun/_bun" ] && source "/Users/swissblock/.bun/_bun"
export PATH="$HOME/.npm-global/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/swissblock/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
