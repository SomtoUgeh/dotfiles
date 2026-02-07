# macOS Applications & Tools

This document lists all the applications and tools installed on the system.

## Homebrew Package Manager

All formulae and casks are defined in the root `Brewfile`. Install them with:

```bash
brew bundle install
```

## Homebrew Formulae (125 packages)

Key development tools installed via Homebrew:

### Version Control & Git Tools
- `git` - Version control system
- `gh` - GitHub CLI
- `hub` - GitHub wrapper for git
- `git-delta` - Better git diff viewer

### Modern CLI Tools
- `bat` - Better cat with syntax highlighting
- `eza` - Modern ls replacement
- `ast-grep` - Code search and rewriting tool

### Programming Languages & Runtimes
- `go` - Go programming language
- Node.js (via `fnm` version manager)
- Bun runtime
- pnpm package manager

### Media Processing
- `ffmpeg` - Video/audio processing
- `caddy` - Modern web server

### Build Tools & Libraries
- `gcc` - GNU Compiler Collection
- `cmake` - Cross-platform build system
- Various libraries (cairo, harfbuzz, etc.)

## Homebrew Casks (12 applications)

### Development
- `visual-studio-code` - Code editor
- `iterm2` (via .config)
- `ngrok` - Localhost tunneling

### Browsers
- `brave-browser`
- `google-chrome`

### Productivity
- `1password-cli` - Password manager CLI
- `slack`
- `discord`

### Utilities
- `dropbox` - Cloud storage
- `spotify` - Music streaming
- `zoom` - Video conferencing

## Shell & Terminal Setup

### Zsh Configuration
- Oh My Zsh framework
- Powerlevel10k theme
- zsh-syntax-highlighting plugin
- fast-syntax-highlighting plugin

### Node.js Version Manager
- `fnm` - Simple Node.js version management

## Additional Tools Installed

### From ~/.config
- iTerm2 - Terminal emulator
- GitHub CLI (gh) - GitHub integration
- Raycast - Productivity launcher
- 1Password - Password manager
- Zed - Code editor

### Python Tools
- `uv` - Python package manager

### Rust Tools
- Cargo (Rust package manager)

## Manual Installation Required

Some applications may need manual installation:

1. **App Store Apps** - Not managed by Homebrew
2. **Font installations** - Install manually or via Font Book
3. **Browser extensions** - Install from respective extension stores
4. **IDE extensions** - VS Code extensions need separate installation

## Notes

- The `Brewfile` in the root directory contains the complete list of all formulae and casks
- Run `brew bundle install` in the dotfiles directory to install everything at once
- Some apps may require additional configuration after installation
