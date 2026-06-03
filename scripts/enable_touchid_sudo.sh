#!/bin/bash
# Enable Touch ID for sudo on macOS.
#
# Uses /etc/pam.d/sudo_local, which survives system updates (unlike editing
# /etc/pam.d/sudo directly). Also wires in pam_reattach when available so
# Touch ID works inside tmux/screen sessions, not just bare terminals.
set -euo pipefail

SUDO_LOCAL="/etc/pam.d/sudo_local"
TEMPLATE="/etc/pam.d/sudo_local.template"

# sudo needs a real TTY to read your password. Run piped, or through an agent
# or the `!` prefix, it can't — so bail with a clear message instead of falsely
# reporting success (the old bug this replaces).
if [ ! -t 0 ] || [ ! -t 1 ]; then
  echo "Error: run this in a real terminal (Ghostty/iTerm/Terminal)." >&2
  echo "sudo needs a TTY to read your password; it can't here." >&2
  exit 1
fi

# sudo_local is a macOS Sonoma+ feature.
if [ ! -f "$TEMPLATE" ] && [ ! -f "$SUDO_LOCAL" ]; then
  echo "Error: $TEMPLATE not found — needs macOS Sonoma or later." >&2
  exit 1
fi

echo "Enabling Touch ID for sudo. You'll be asked for your password once."
sudo -v  # prompt + cache credentials up front; exits here (set -e) if it fails

# pam_reattach makes Touch ID work inside tmux/screen. Optional but recommended
# on this machine, which uses tmux/cmux.
pam_reattach=""
for p in /opt/homebrew/lib/pam/pam_reattach.so /usr/local/lib/pam/pam_reattach.so; do
  [ -f "$p" ] && pam_reattach="$p" && break
done
if [ -z "$pam_reattach" ]; then
  echo "Note: pam_reattach not found — Touch ID won't work inside tmux/screen."
  echo "      To enable there: brew install pam-reattach, then re-run this script."
fi

# Declare the desired sudo_local content (idempotent — safe to re-run).
# pam_reattach must come before pam_tid in the stack.
{
  echo "# sudo_local — managed by dotfiles scripts/enable_touchid_sudo.sh"
  [ -n "$pam_reattach" ] && echo "auth       optional       $pam_reattach"
  echo "auth       sufficient     pam_tid.so"
} | sudo tee "$SUDO_LOCAL" >/dev/null

# Verify the result instead of blindly claiming success.
if grep -qE '^auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' "$SUDO_LOCAL"; then
  echo "Touch ID for sudo is enabled."
  echo "Test it: sudo -k && sudo ls"
else
  echo "Error: pam_tid line not active in $SUDO_LOCAL after edit." >&2
  exit 1
fi
