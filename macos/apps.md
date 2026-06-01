# macOS Applications & Tools

Accurate inventory of what is installed on this machine and how to reproduce it
on a new Mac. The `Brewfile` at the repo root is the source of truth for anything
installable via Homebrew or the Mac App Store; this file documents the full
picture, including things that must be installed by hand.

## How to reproduce on a new Mac

```bash
brew bundle install   # installs all formulae, casks, and MAS apps below
```

Sign in to the **App Store** first, or the `mas` lines will fail.

---

## Installed via Homebrew — CLI (formulae)

Core: `bat`, `eza`, `fzf`, `ripgrep`, `tree`, `trash`, `jq`, `tmux`, `direnv`, `pandoc`
Git: `git`, `git-delta`, `git-filter-repo`, `gh`, `hub`, `graphite`, `acli`
Dev: `ast-grep`, `fnm` (Node), `go`, `rust`, `watchman`, `starship`
Cloud/infra: `neonctl`, `hcloud`, `rclone`, `caddy`, `mkcert`, `nss`, `ngrok`
Media: `ffmpeg`, `imagemagick`
DB: `postgresql@17`
Python: `uv`
Shell: `zsh`, `zsh-autosuggestions`, `zsh-syntax-highlighting`
App Store: `mas`

> Transitive dependencies (cmake, poppler, librsvg, woff2, qrencode, gecode, etc.)
> are installed automatically and are intentionally not listed in the Brewfile.

## Installed via Homebrew — Apps (casks)

Editors/terminals: Cursor, VS Code, Zed, Ghostty, iTerm2
Dev: OrbStack, TablePlus, Postman, LM Studio, gcloud CLI
AI: Claude, Granola, superwhisper
Browsers/comms: Google Chrome, Slack, Discord, Telegram, Notion
Utilities: Raycast, AltTab, Bartender, Alcove, BetterMouse, Cap, 1Password, 1Password CLI
Storage/media: Dropbox, Spotify
Networking: Tailscale, Cloudflare WARP, Surfshark, Termius
Fonts: JetBrains Mono Nerd Font, Zed Mono Nerd Font

## Installed via Mac App Store (`mas`)

1Password for Safari, Amphetamine, Hidden Bar, Spark, WhatsApp,
Keynote, Numbers, Pages, Xcode, TestFlight.

---

## Manual installs (no reliable brew/MAS source)

- **Dia browser** (The Browser Company) — https://www.diabrowser.com
- **Paper.app** — verify the official source before scripting it
- **Developer.app** — Apple developer companion (ships via Xcode / App Store)

## Installed by other tools, not standalone (do not script)

- **Codex** — Codex CLI desktop component
- **cmux** — spawned by tooling
- **Sotto** — dictation helper
- **Claude Code URL Handler** (~/Applications) — created by Claude Code
- **Raycast Beta** — beta channel of Raycast (the stable cask is `raycast`)

---

## Notes / decisions

- **Node:** `fnm` is the chosen version manager. `mise` was installed but is not
  carried over to avoid overlap.
- **Postgres:** consolidated to `postgresql@17`. `@14` and `@16` are dropped.
- **Docker:** OrbStack is the chosen runtime; Docker Desktop is not in the Brewfile.
- Browser extensions and IDE extensions still need to be installed per-app.
