#!/usr/bin/env bash
# Install t3-events on this Mac: the ~/.local/bin/t3-events wrapper and the com.julds.t3-events
# LaunchAgent that keeps `t3-events run` going. Safe to run again. Sign-ins are separate:
# see agents/t3-events.md (`t3-events login <env> <mcp-url> ...`).
set -euo pipefail
DOTFILES=$(cd "$(dirname "$0")/.." && pwd)
NODE=${T3_EVENTS_NODE:-$HOME/.local/share/fnm/aliases/default/bin/node}
[ -x "$NODE" ] || NODE=$(command -v node)
[ -x "$NODE" ] || { echo "node not found; set T3_EVENTS_NODE" >&2; exit 1; }
BIN=$HOME/.local/bin/t3-events
PLIST=$HOME/Library/LaunchAgents/com.julds.t3-events.plist
mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

cat > "$BIN" <<EOF
#!/bin/sh
# t3-events: T3 Code MCP Events bridge for Aside. Source: $DOTFILES/scripts/t3_events.mjs
exec "$NODE" "$DOTFILES/scripts/t3_events.mjs" "\$@"
EOF
chmod 755 "$BIN"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.julds.t3-events</string>
  <key>ProgramArguments</key><array><string>$BIN</string><string>run</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/t3-events.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/t3-events.log</string>
</dict></plist>
EOF
plutil -lint "$PLIST" >/dev/null

if launchctl print "gui/$(id -u)/com.julds.t3-events" >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$(id -u)/com.julds.t3-events"
else
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
fi
echo "t3-events installed. Sign in each T3 environment: t3-events login <env> <mcp-url> --environment-id <id>"
