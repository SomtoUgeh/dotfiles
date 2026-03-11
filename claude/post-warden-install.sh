#!/usr/bin/env bash
# post-warden-install.sh — Run after ./install.sh to restore custom hooks + statusline
#
# Usage:
#   cd ~/dev/claude-warden && ./install.sh --profile standard
#   ~/code/dotfiles/claude/post-warden-install.sh

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
DOTFILES_SETTINGS="$HOME/code/dotfiles/claude/settings.json"
DOTFILES_STATUSLINE="$HOME/code/dotfiles/claude/statusline.sh"

# 1. Add git_guard.py to PreToolUse (after warden's * matcher, before Read matcher)
jq '.hooks.PreToolUse |= (
  if any(.matcher == "Bash" and (.hooks | any(.command | test("git_guard")))) then .
  else [.[0]] + [{
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": "python3 ~/.claude/hooks/git_guard.py", "timeout": 5}]
  }] + .[1:]
  end
)' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

# 2. Add shaping-ripple.sh to PostToolUse (after warden's matchers)
jq '.hooks.PostToolUse |= (
  if any(.matcher == "Write|Edit") then .
  else . + [{
    "matcher": "Write|Edit",
    "hooks": [{"type": "command", "command": "~/.claude/skills/shaping/shaping-ripple.sh", "timeout": 5}]
  }]
  end
)' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

# 3. Restore symlink to dotfiles settings
cp "$SETTINGS" "$DOTFILES_SETTINGS"
rm "$SETTINGS"
ln -s "$DOTFILES_SETTINGS" "$SETTINGS"

# 4. Restore statusline symlink
rm -f "$HOME/.claude/statusline.sh"
ln -s "$DOTFILES_STATUSLINE" "$HOME/.claude/statusline.sh"

echo "Done: git_guard.py + shaping-ripple.sh restored, symlinks fixed."
