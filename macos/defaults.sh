#!/usr/bin/env bash

# macOS System Preferences & Defaults
# Run this script to configure macOS system settings

echo "Configuring macOS system preferences..."

# =============================================================================
# General UI/UX
# =============================================================================

# Enable Dark Mode
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable minimizing windows on double-click
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false

# Enable full keyboard access for all controls (Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# Disable swipe navigation
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false

# =============================================================================
# Keyboard Speed (IMPORTANT for coding)
# =============================================================================

# Key repeat rate: 1 = fastest (15ms between repeats)
defaults write NSGlobalDomain KeyRepeat -int 1

# Delay until repeat: 15 = shortest delay before key starts repeating
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# =============================================================================
# Locale
# =============================================================================

# Use British English locale
defaults write NSGlobalDomain AppleLocale -string "en_GB"
defaults write NSGlobalDomain AppleLanguages -array "en-GB"

# =============================================================================
# Finder
# =============================================================================

# Show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Use list view in all Finder windows by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# =============================================================================
# Dock
# =============================================================================

# Set the icon size of Dock items
defaults write com.apple.dock tilesize -int 48

# Don't show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# =============================================================================
# Screenshots
# =============================================================================

# Save screenshots to Pictures/Screenshots
mkdir -p "${HOME}/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"

# Save screenshots in PNG format
defaults write com.apple.screencapture type -string "png"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# =============================================================================
# Energy & Battery
# =============================================================================

# Disable automatic system sleep
sudo pmset -a sleep 0

# Display sleep after 15 minutes
sudo pmset -a displaysleep 15

# =============================================================================
# Terminal
# =============================================================================

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# =============================================================================
# Trackpad
# =============================================================================

# Enable tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# =============================================================================
# Restart affected applications
# =============================================================================

echo ""
echo "Done! Some changes require a logout/restart to take effect."
echo ""
echo "To apply keyboard settings immediately, you may need to log out and back in."
echo ""
echo "To restart Finder and Dock now, run:"
echo "  killall Finder Dock SystemUIServer"
