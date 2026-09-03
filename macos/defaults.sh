#!/usr/bin/env bash
#
# macOS system preferences.
#
# Merged source of truth: the previous macos/defaults.sh (25 settings) plus a
# line-by-line review of the mathiasbynens/kentcdodds lineage. Do not keep a
# second defaults script - two of them fight, and last-to-run wins.
# Run once on a new machine:  ./.macos
#
# Derived from the mathiasbynens/kentcdodds lineage, reviewed line by line.
# Deliberately omitted: LSQuarantine disabling, disk-image skip-verify, and
# `chmod 600` on a /System binary. Those weaken download and image
# verification, which we keep on.

set -e

# Close System Settings so it can't overwrite what we set here.
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

# Ask for the admin password up front, then keep the sudo timestamp alive
# until this script finishes.
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Some preference domains are TCC-protected (Safari, Mail, Messages) or need
# Accessibility permission (universalaccess). Writing them from a terminal
# without that permission fails outright, which under `set -e` would abort the
# whole run. Wrap those writes so a refusal is reported and skipped instead.
try_write() {
  if ! "$@" 2>/dev/null; then
    echo "  ! skipped (needs Full Disk Access / Accessibility): $*"
  fi
}

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Disable the startup chime
sudo nvram SystemAudioVolume=" "

# Expand the save and print panels by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Quit the printer app once the print jobs are done
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Help Viewer behaves as a normal window instead of floating above everything
defaults write com.apple.helpviewer DevMode -bool true

# Dark mode
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# Don't minimize windows on double-clicking the title bar
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false

# No two-finger swipe navigation (applies system-wide, incl. browsers)
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false

# Disable the text substitutions that quietly corrupt code, shell commands
# and commit messages.
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

###############################################################################
# Locale                                                                      #
###############################################################################

# British English
defaults write NSGlobalDomain AppleLanguages -array "en-GB"
defaults write NSGlobalDomain AppleLocale -string "en_GB"

###############################################################################
# Trackpad, keyboard and input                                                #
###############################################################################

# Trackpad: tap to click, for this user and for the login screen.
# Both trackpad domains are set: AppleBluetoothMultitouch.trackpad is the
# external Magic Trackpad, AppleMultitouchTrackpad is the built-in one.
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Trackpad: three-finger drag
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -int 1

# Full keyboard access for all controls (tab through every dialog control)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# Key repeat instead of the accent picker when holding a key.
# Essential for vim-style navigation in any editor.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Key repeat rate, faster than System Settings allows.
# NOTE: needs a logout/restart to take effect; opening the Keyboard pane in
# System Settings can reset these to slider-legal values.
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Ctrl + scroll wheel to zoom the screen, following the keyboard focus.
# May no-op unless the calling terminal has Accessibility permission.
try_write defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
try_write defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144

###############################################################################
# Screen                                                                      #
###############################################################################

# Require a password immediately after sleep or screen saver.
# NOTE: on Ventura+ these keys are largely ignored; macOS moved this to
# System Settings -> Lock Screen. Set it there too and verify.
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Screenshots: PNG, to the Desktop, without the huge window drop shadow
defaults write com.apple.screencapture location -string "${HOME}/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# Expose HiDPI scaled resolutions (for the external monitor)
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

###############################################################################
# Finder                                                                      #
###############################################################################

# Show all filename extensions.
# Defensive as well as tidy: hidden extensions are how a payload presents
# itself as a font or an image.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show hidden (dot) files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show the status bar and path bar
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true

# Full POSIX path as the Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Search the current folder by default rather than the whole Mac
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# No warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# New Finder windows open in ~/code
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/code/"

# Icon view by default
# Other view modes: `icnv` (icon), `clmv` (column), `Flwv` (gallery), `Nlsv` (list)
defaults write com.apple.finder FXPreferredViewStyle -string "icnv"

# Allow quitting Finder with Cmd-Q (this also hides the desktop icons)
defaults write com.apple.finder QuitMenuItem -bool true

# No confirmation when emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Which mounted volumes show on the Desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false

# Spring loading for directories, with a short delay
defaults write NSGlobalDomain com.apple.springing.enabled -bool true
defaults write NSGlobalDomain com.apple.springing.delay -float 0.2

# Don't write .DS_Store on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Expand the General, Open With, and Sharing & Permissions Info panes
defaults write com.apple.finder FXInfoPanesExpanded -dict \
  General -bool true \
  OpenWith -bool true \
  Privileges -bool true

# Show the ~/Library and /Volumes folders
chflags nohidden ~/Library
sudo chflags nohidden /Volumes

# NOTE: deliberately NOT set here (from the upstream script):
#   com.apple.frameworks.diskimages skip-verify{,-locked,-remote}
#     -> disables checksum verification on disk images, including remote ones
#   com.apple.frameworks.diskimages auto-open-{ro,rw}-root
#   com.apple.finder OpenWindowForNewRemovableDisk
#     -> auto-opens a window for any volume that mounts
#   nine PlistBuddy desktop icon-view tweaks
#     -> `Set` fails when the key is absent, which aborts this script under
#        `set -e`. Cosmetic only; use Cmd-J in a Finder window instead.

###############################################################################
# Dock and Mission Control                                                    #
###############################################################################

# Small icons: the Dock here is a status strip, not a launcher
defaults write com.apple.dock tilesize -int 16

# Wipe the pinned apps and show only what is running.
# WARNING: `persistent-apps -array` is destructive and re-runs. If you ever
# curate the Dock by hand, comment this line out before running again.
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock static-only -bool true

# Auto-hide, with no delay and no slide animation
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0

# Hidden applications show as translucent icons
defaults write com.apple.dock showhidden -bool true

# Scale rather than genie, and minimize into the app's own icon
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.dock minimize-to-application -bool true

# Indicator lights under running apps
defaults write com.apple.dock show-process-indicators -bool true

# Spring loading on all Dock items, and hover highlight in stack grid view
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
defaults write com.apple.dock mouse-over-hilite-stack -bool true

# No launch bounce, and a fast Mission Control
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1

# Don't reorder Spaces by most recent use (keeps Ctrl-1/Ctrl-2 stable)
defaults write com.apple.dock mru-spaces -bool false

# No "recent applications" section in the Dock
defaults write com.apple.dock show-recents -bool false

# Disable the pinch-to-Launchpad gesture
defaults write com.apple.dock showLaunchpadGestureEnabled -int 0

# Hot corners deliberately not configured.

###############################################################################
# Safari and WebKit                                                           #
###############################################################################
# NOTE: Safari is sandboxed into a TCC-protected container. These writes are
# silently dropped unless the terminal running this script has Full Disk
# Access (System Settings -> Privacy & Security -> Full Disk Access).
# No error is reported when they fail. Verify with:
#   defaults read com.apple.Safari AutoOpenSafeDownloads

# Don't auto-open "safe" files after downloading them.
# The single most important line in this section: it removes the
# open-on-arrival behaviour that download-borne payloads rely on.
try_write defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Show the full URL in the address bar, so a lookalike domain is visible
try_write defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Warn about fraudulent websites
try_write defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

# Don't send search queries to Apple
try_write defaults write com.apple.Safari UniversalSearchEnabled -bool false
try_write defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# Send Do Not Track
try_write defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

# Keep extensions updated automatically
try_write defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

# No autofill: 1Password handles credentials and cards
try_write defaults write com.apple.Safari AutoFillFromAddressBook -bool false
try_write defaults write com.apple.Safari AutoFillPasswords -bool false
try_write defaults write com.apple.Safari AutoFillCreditCardData -bool false
try_write defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false

# Develop menu and Web Inspector
try_write defaults write com.apple.Safari IncludeDevelopMenu -bool true
try_write defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
try_write defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

###############################################################################
# Mail                                                                        #
###############################################################################

# Copy bare email addresses, without the display name
try_write defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

# Threaded message view in drafts
try_write defaults write com.apple.mail DraftsViewerAttributes -dict-add "DisplayInThreadedMode" -string "yes"

###############################################################################
# Software Update                                                             #
###############################################################################
# These are system-level preferences. The upstream script writes them to the
# user domain, where they silently no-op on current macOS; they belong in
# /Library/Preferences and need sudo.

# Check for updates daily, and download them automatically
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ScheduleFrequency -int 1
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install Rapid Security Responses automatically
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Keep XProtect / MRT / Gatekeeper malware definitions current.
# This is the malware signature feed. Leave it on.
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -int 1

# Auto-update apps from the App Store (per-user)
defaults write com.apple.commerce AutoUpdate -bool true

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window on launch, all processes, sorted by CPU descending
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
defaults write com.apple.ActivityMonitor ShowCategory -int 0
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# Photos and Messages                                                         #
###############################################################################

# Don't let Photos launch itself when a device is connected
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# No emoji or quote substitution, and no spell check, in Messages
try_write defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticEmojiSubstitutionEnablediMessage" -bool false
try_write defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false
try_write defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "continuousSpellCheckingEnabled" -bool false

###############################################################################
# Terminal.app                                                                #
###############################################################################
# Ghostty is the daily terminal; these only matter on the occasions
# Terminal.app is opened.

# UTF-8 only
defaults write com.apple.terminal StringEncodings -array 4

###############################################################################
# Apply                                                                       #
###############################################################################

for app in "Activity Monitor" \
  "cfprefsd" \
  "Dock" \
  "Finder" \
  "Messages" \
  "Safari" \
  "SystemUIServer"; do
  killall "${app}" &> /dev/null || true
done

echo
echo "Done! Some changes require a logout/restart to take effect."
echo
echo "Two things do not apply until you log out or restart:"
echo "  - KeyRepeat / InitialKeyRepeat"
echo "  - some Dock and Finder state"
echo
echo "The Safari block needs Full Disk Access for the terminal running this"
echo "script. Verify it landed with:"
echo "  defaults read com.apple.Safari AutoOpenSafeDownloads   # expect 0"
