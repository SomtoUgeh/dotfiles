#!/bin/bash
# Post-install wrapper for claude-warden
# Runs warden install, then restores all dotfiles-managed overrides
set -euo pipefail

WARDEN_DIR="$HOME/dev/claude-warden"
DOTFILES_CLAUDE="$HOME/code/dotfiles/claude"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

# --- Save dotfiles-managed settings before warden overwrites ---
saved_file_suggestion=""
if [ -f "$SETTINGS" ]; then
  saved_file_suggestion=$(jq -c '.fileSuggestion // empty' "$SETTINGS")
fi

# --- Run warden installer (pass all args through) ---
"$WARDEN_DIR/install.sh" "$@"

# --- Restore dotfiles statusline ---
rm -f "$CLAUDE_DIR/statusline.sh"
ln -s "$DOTFILES_CLAUDE/statusline.sh" "$CLAUDE_DIR/statusline.sh"
echo "[dotfiles] Restored statusline"

# --- Restore dotfiles hook scripts (symlinks into hooks/) ---
ln -sf "$DOTFILES_CLAUDE/hooks/git_guard.py" "$CLAUDE_DIR/hooks/git_guard.py"
echo "[dotfiles] Restored hooks/git_guard.py"

# --- Re-inject custom hook entries into settings.json ---
# Add new custom hooks here as additional jq expressions
tmp=$(mktemp)
jq '
  .hooks.PreToolUse += [{
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": "python3 ~/.claude/hooks/git_guard.py", "timeout": 5}]
  }]
  | .hooks.PostToolUse += [{
    "matcher": "Write|Edit",
    "hooks": [{"type": "command", "command": "~/.claude/skills/shaping/shaping-ripple.sh", "timeout": 5}]
  }]
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
echo "[dotfiles] Injected custom hooks (git_guard, shaping-ripple)"

# --- Restore fileSuggestion if warden clobbered it ---
if [ -n "$saved_file_suggestion" ]; then
  tmp=$(mktemp)
  jq --argjson fs "$saved_file_suggestion" '.fileSuggestion = $fs' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "[dotfiles] Restored fileSuggestion"
fi

echo "[dotfiles] Done. Start a new Claude Code session to activate."
