# Dotfiles

Personal macOS development environment configuration and setup scripts.

## Overview

This repository contains configuration files, scripts, and documentation for quickly setting up a new Mac development environment. It includes shell configurations, application settings, Homebrew packages, and more.

## What's Included

- **Shell Configuration**: Zsh with Oh My Zsh and Powerlevel10k theme
- **Git Configuration**: Aliases, delta integration, and global settings
- **Application Configs**: iTerm2, VS Code, Raycast, GitHub CLI, and more
- **Claude Code**: Custom commands, settings, and configurations
- **Custom Scripts**: Utility scripts and tools
- **Homebrew**: Complete package list (125 formulae + 12 casks)
- **macOS Settings**: System preferences and defaults

## Prerequisites

Before running the installation, ensure you have:

1. **macOS** (tested on macOS Sequoia 15.0)
2. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```
3. **Homebrew** - Package manager for macOS
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

## Quick Start

### 1. Clone This Repository

```bash
git clone https://github.com/yourusername/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
```

### 2. Run the Installation Script

```bash
./install.sh
```

This will:
- Create symlinks for all configuration files
- Install Homebrew packages from Brewfile
- Set up shell configuration
- Create necessary directories

### 3. Configure Sensitive Files

Copy and configure these files manually (templates provided in `templates/`):

```bash
# SSH Configuration
cp templates/ssh-config.template ~/.ssh/config
chmod 600 ~/.ssh/config

# AWS Configuration (if needed)
mkdir -p ~/.aws
cp templates/aws-config.template ~/.aws/config
# Edit ~/.aws/config and ~/.aws/credentials with your actual values

# Generate new SSH key if needed
ssh-keygen -t ed25519 -C "your_email@example.com"
```

### 4. Install Oh My Zsh and Powerlevel10k

```bash
# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Powerlevel10k theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install zsh plugins
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
```

### 5. Apply macOS System Preferences

```bash
./macos/defaults.sh
```

Review the script before running to ensure you agree with all settings.

### 6. Install Additional Tools

```bash
# Node.js version manager
curl -L https://git.io/n-install | bash

# Python package manager (uv)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 7. Restart Your Terminal

Close and reopen your terminal, or run:
```bash
exec zsh
```

## Manual Steps

### Applications

Some applications need manual installation or configuration:

1. **App Store Applications** - Install from the Mac App Store
2. **1Password** - Sign in and configure browser integration
3. **VS Code Extensions** - Install from Extensions marketplace
4. **Browser Extensions** - Install from respective stores

### SSH Keys

If you have existing SSH keys from your old Mac:

```bash
# Copy your private key
cp /path/to/old/key ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519

# Copy your public key
cp /path/to/old/key.pub ~/.ssh/id_ed25519.pub

# Add to SSH agent
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Add to GitHub/GitLab/etc
pbcopy < ~/.ssh/id_ed25519.pub  # Then paste in GitHub settings
```

### Git Configuration

Update git config with your personal information:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Repository Structure

```
dotfiles/
├── README.md                    # This file
├── Brewfile                     # Homebrew packages
├── install.sh                   # Installation script
├── shell/                       # Shell configurations
│   ├── .zshrc
│   ├── .zshenv
│   ├── .zprofile
│   └── .p10k.zsh
├── git/                         # Git configuration
│   ├── .gitconfig
│   └── .gitignore_global
├── config/                      # Application configs
├── claude/                      # Claude Code configuration
├── scripts/                     # Custom scripts
├── npm/                         # npm configuration
├── macos/                       # macOS-specific
│   ├── defaults.sh
│   └── apps.md
└── templates/                   # Sensitive file templates
    ├── ssh-config.template
    ├── aws-config.template
    └── env.template
```

## Key Features

### Shell Configuration

- **Zsh** with Oh My Zsh framework
- **Powerlevel10k** theme for a beautiful prompt
- Custom functions and aliases
- PATH configuration for various tools (Node, Bun, pnpm, etc.)

### Git Configuration

- Useful aliases (a, c, p, l, etc.)
- Delta integration for better diffs
- Automatic rebase on pull
- Case-sensitive file handling

### Custom Scripts

- `gcauto` - Git commit automation
- `install-agent-guides.sh` - Install agent guides in projects
- `hermit` - Hermit package manager

## Updating

To update your dotfiles:

```bash
cd ~/code/dotfiles
git pull
./install.sh  # Re-run to update symlinks if needed
```

## Troubleshooting

### Zsh completion issues

```bash
rm -f ~/.zcompdump*
exec zsh
```

### Homebrew installation fails

```bash
brew doctor
brew update
brew bundle install
```

### Symlinks not working

```bash
# Remove existing file and re-run install
rm ~/.zshrc
./install.sh
```

### Permission issues with scripts

```bash
chmod +x scripts/*
chmod +x macos/defaults.sh
chmod +x install.sh
```

## Customization

Feel free to customize these dotfiles for your needs:

1. Fork this repository
2. Modify configurations in each directory
3. Update the Brewfile with your preferred packages
4. Adjust macOS defaults in `macos/defaults.sh`
5. Commit and push your changes

## Security Notes

⚠️ **Important**: This repository does NOT include:
- SSH private keys
- AWS credentials
- API keys or secrets
- .env files with sensitive data

Templates are provided in `templates/` directory. Configure these manually on your new machine.

## Resources

- [Oh My Zsh](https://ohmyz.sh/)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [Homebrew](https://brew.sh/)
- [git-delta](https://github.com/dandavison/delta)
- [Claude Code](https://docs.claude.com/claude-code)

## License

These are personal configuration files. Feel free to use and modify as needed.
