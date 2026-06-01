# Homebrew Bundle
# Install with: brew bundle install
#
# Curated for a clean new-Mac setup. Reflects what is actually used, not every
# transitive dependency. Dependencies (cmake, poppler, librsvg, woff2, ...) are
# pulled in automatically and intentionally left out.

# =============================================================================
# Taps
# =============================================================================
tap "ngrok/ngrok"
tap "withgraphite/tap"        # graphite (stacked PRs)
tap "atlassian/acli"          # Jira CLI

# =============================================================================
# CLI Tools (formulae)
# =============================================================================

# Core utilities
brew "bat"                    # Better cat with syntax highlighting
brew "eza"                    # Modern ls replacement
brew "fzf"                    # Fuzzy finder
brew "ripgrep"                # Fast grep alternative
brew "tree"                   # Directory tree view
brew "trash"                  # Move to trash instead of rm
brew "jq"                     # JSON processor
brew "tmux"                   # Terminal multiplexer
brew "direnv"                 # Per-directory environment variables
brew "pandoc"                 # Document converter

# Git & GitHub
brew "git"
brew "git-delta"              # Better git diff
brew "git-filter-repo"        # Rewrite git history
brew "gh"                     # GitHub CLI
brew "hub"                    # GitHub wrapper for git
brew "graphite"               # Stacked PRs CLI
brew "acli"                   # Atlassian / Jira CLI

# Development
brew "ast-grep"               # Structural code search
brew "fnm"                    # Fast Node Manager (Node version manager)
brew "go"
brew "rust"                   # Rust toolchain (cargo)
brew "watchman"               # File watcher (React Native / Metro)
brew "starship"               # Cross-shell prompt

# Cloud / infra CLIs
brew "neonctl"                # Neon Postgres CLI
brew "hcloud"                 # Hetzner Cloud CLI
brew "rclone"                 # Cloud storage CLI
brew "caddy"                  # Web server
brew "mkcert"                 # Local HTTPS certs
brew "nss"                    # Required by mkcert for Firefox

# Media
brew "ffmpeg"
brew "imagemagick"            # Image manipulation

# Database
brew "postgresql@17"          # Single Postgres version (was @14/@16/@17)

# Python
brew "uv"                     # Fast Python package manager

# Shell
brew "zsh"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"

# App Store CLI
brew "mas"                    # Install Mac App Store apps (see bottom of file)

# =============================================================================
# Applications (Casks)
# =============================================================================

# Editors & terminals
cask "cursor"                 # Primary editor (AI VSCode fork)
cask "visual-studio-code"     # Shares config with Cursor
cask "zed"                    # Fast modern editor
cask "ghostty"                # GPU-accelerated terminal
cask "iterm2"                 # Backup terminal

# Dev tooling
cask "orbstack"               # Docker/Linux VMs (lightweight Docker Desktop alt)
cask "tableplus"             # Database GUI
cask "postman"                # API client
cask "lm-studio"              # Local LLM runner
cask "gcloud-cli"             # Google Cloud SDK
cask "ngrok"                  # Localhost tunneling (ngrok/ngrok tap)

# AI / assistants
cask "claude"                 # Claude desktop app
cask "granola"                # Meeting notes
cask "superwhisper"           # Local dictation

# Browsers & communication
cask "google-chrome"
cask "slack"
cask "discord"
cask "telegram"
cask "notion"

# Productivity & utilities
cask "raycast"                # Launcher
cask "alt-tab"                # Windows-style app switcher
cask "bartender"              # Menu bar management
cask "alcove"                 # Notch / Dynamic Island utility
cask "bettermouse"           # Mouse customization
cask "cap"                    # Screen recorder
cask "1password"
cask "1password-cli"

# Storage & media
cask "dropbox"
cask "spotify"

# Networking / VPN
cask "tailscale"
cask "cloudflare-warp"
cask "surfshark"
cask "termius"                # SSH client

# Fonts
cask "font-jetbrains-mono-nerd-font"
cask "font-zed-mono-nerd-font"

# =============================================================================
# Mac App Store (requires being signed into the App Store first)
# =============================================================================
mas "1Password for Safari", id: 1569813296
mas "Amphetamine",          id: 937984704
mas "Hidden Bar",           id: 1452453066
mas "Spark",                id: 1176895641
mas "WhatsApp",             id: 310633997
mas "Keynote",              id: 409183694
mas "Numbers",              id: 409203825
mas "Pages",                id: 409201541
mas "Xcode",                id: 497799835
mas "TestFlight",           id: 899247664

# =============================================================================
# NOT in this Brewfile — install manually (no reliable brew/MAS source)
# =============================================================================
# - Dia browser (The Browser Company)  -> https://www.diabrowser.com  (direct download)
# - Paper.app                          -> verify source before scripting
# - Codex, cmux, Sotto                 -> installed by other CLIs/tools, not standalone
