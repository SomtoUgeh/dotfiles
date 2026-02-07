#!/usr/bin/env bash
# scheduled-session-sync.sh - Cron/launchd wrapper for session sync
#
# Runs incremental sync, then qmd update + embed. Logs to ~/.claude/session-sync.log
# with rotation at 1MB.

set -euo pipefail

LOG_FILE="$HOME/.claude/session-sync.log"
MAX_LOG_SIZE=1048576  # 1MB

# Cross-platform filesize (GNU/BSD stat)
get_filesize() {
  local file="$1" size="0"
  if size=$(stat -c %s "$file" 2>/dev/null); then
    :
  elif size=$(stat -f %z "$file" 2>/dev/null); then
    :
  else
    size=0
  fi
  [[ "$size" =~ ^[0-9]+$ ]] || size=0
  printf '%s' "$size"
}

mkdir -p "$(dirname "$LOG_FILE")"

# Rotate log if too large
if [[ -f "$LOG_FILE" ]] && [[ $(get_filesize "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
  mv "$LOG_FILE" "${LOG_FILE}.old"
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "Starting scheduled session sync"

# Require qmd
if ! command -v qmd &>/dev/null; then
  log "qmd not found, skipping"
  exit 0
fi

# Locate sync script (sibling to this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync-sessions-to-qmd.sh"

if [[ ! -x "$SYNC_SCRIPT" ]]; then
  log "Sync script not found or not executable: $SYNC_SCRIPT"
  exit 1
fi

# Run incremental sync
log "Running incremental sync..."
if "$SYNC_SCRIPT" >> "$LOG_FILE" 2>&1; then
  log "Sync completed"
else
  log "Sync failed (exit $?)"
fi

# Update qmd index
log "Running qmd update..."
if qmd update >> "$LOG_FILE" 2>&1; then
  log "Update completed"
else
  log "Update failed (exit $?)"
fi

# Update embeddings
log "Running qmd embed..."
if qmd embed >> "$LOG_FILE" 2>&1; then
  log "Embed completed"
else
  log "Embed failed (exit $?)"
fi

log "Scheduled sync complete"
