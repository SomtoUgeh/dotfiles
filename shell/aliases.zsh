# Aliases and functions shared by shell/.zshrc (personal Mac) and
# work/zsh/zshrc (work Mac). Put personal-only commands in shell/.zshrc.

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
  /Applications/Zed.app/Contents/MacOS/cli ${@:-.} > /dev/null 2>&1 & disown
}

# Git commit
gc() { git commit -m "$@"; }

# Git diff
dif() { git diff --no-index "$1" "$2" | delta; }
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
