#!/usr/bin/env bash
# setup-session-sync.sh - Install daily 1am cron/launchd for session sync
#
# macOS: creates launchd plist (StartCalendarInterval, runs missed jobs on wake)
# Linux: adds crontab entry (0 1 * * *)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/scheduled-session-sync.sh"

if [[ ! -f "$SYNC_SCRIPT" ]]; then
  echo "Error: scheduled-session-sync.sh not found at $SYNC_SCRIPT" >&2
  exit 1
fi
chmod +x "$SYNC_SCRIPT"
chmod +x "$SCRIPT_DIR/sync-sessions-to-qmd.sh"

LABEL="com.claude.session-sync"

install_launchd() {
  local plist_dir="$HOME/Library/LaunchAgents"
  local plist_path="$plist_dir/$LABEL.plist"

  mkdir -p "$plist_dir"

  cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SYNC_SCRIPT</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>1</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>$HOME/.claude/session-sync-launchd.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/.claude/session-sync-launchd.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
EOF

  # Unload if already loaded, then load
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist_path"

  echo "Installed launchd agent: $LABEL"
  echo "  Plist: $plist_path"
  echo "  Schedule: daily at 1:00 AM"
  echo "  Log: ~/.claude/session-sync-launchd.log"
}

install_cron() {
  local cron_cmd="0 1 * * * $SYNC_SCRIPT"
  local current_cron

  # Preserve existing crontab, add/replace our entry
  current_cron=$(crontab -l 2>/dev/null || true)

  if echo "$current_cron" | grep -qF "$SYNC_SCRIPT"; then
    echo "Cron entry already exists for session sync"
    return 0
  fi

  (echo "$current_cron"; echo "$cron_cmd") | crontab -

  echo "Installed cron entry:"
  echo "  $cron_cmd"
}

case "$(uname -s)" in
  Darwin)
    install_launchd
    ;;
  Linux)
    install_cron
    ;;
  *)
    echo "Unsupported platform: $(uname -s)" >&2
    echo "Manually schedule: $SYNC_SCRIPT" >&2
    exit 1
    ;;
esac
