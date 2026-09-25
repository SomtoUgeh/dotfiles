#!/usr/bin/env bash
# Check Portal QA prerequisites. Prints names and statuses only — never secret values.
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="${ALTSCHOOL_WEB_PLATFORMS:-$HOME/code/TalentQL/altschool-web-platforms}"
agent_home="${AGENT_BROWSER_HOME:-$HOME/.agent-browser}"
fail=0
warn_count=0

note() { printf '%s\n' "$*"; }
ok() { printf 'ok    %s\n' "$*"; }
warn_msg() { printf 'warn  %s\n' "$*"; warn_count=$((warn_count + 1)); }
err() { printf 'fail  %s\n' "$*"; fail=1; }

note "altschool-portal-qa preflight"
note "skill: $skill_dir"

if command -v agent-browser >/dev/null 2>&1; then
  ok "agent-browser $(agent-browser --version 2>/dev/null | head -1)"
else
  err "agent-browser is not on PATH"
fi
warn_msg "Codex in-app browser is a Desktop session tool, not this CLI. Use it when @Browser / iab APIs exist this turn; production encrypted login still uses agent-browser."

if command -v op >/dev/null 2>&1; then
  if op whoami >/dev/null 2>&1; then
    ok "1Password CLI signed in"
  else
    warn_msg "1Password CLI present but not signed in — use encrypted auth profiles or run: op signin --account my"
  fi
else
  warn_msg "1Password CLI (op) is not on PATH"
fi

if [[ -d "$repo" ]]; then
  ok "repo $repo"
else
  err "repo not found: $repo"
fi

if [[ -f "$repo/.env.example" ]]; then
  ok "root .env.example present (do not read .env.local)"
fi

enc_key="$agent_home/.encryption-key"
if [[ -f "$enc_key" ]]; then
  mode="$(stat -c '%a' "$enc_key" 2>/dev/null || echo unknown)"
  if [[ "$mode" == "600" || "$mode" == "400" ]]; then
    ok "agent-browser encryption key present (mode $mode, not printed)"
  else
    warn_msg "encryption key present but mode is $mode (want 600)"
  fi
else
  warn_msg "no $enc_key — auth profiles and session state may be plaintext"
fi

if command -v agent-browser >/dev/null 2>&1; then
  profiles="$(agent-browser auth list 2>/dev/null || true)"
  if printf '%s\n' "$profiles" | grep -q 'altschool-portal-diagnosis'; then
    ok "auth profile altschool-portal-diagnosis"
  else
    err "missing encrypted auth profile altschool-portal-diagnosis"
  fi
  if printf '%s\n' "$profiles" | grep -q 'altschool-portal-local'; then
    ok "auth profile altschool-portal-local"
  else
    warn_msg "no altschool-portal-local — local portal login needs this or a 1Password stdin save"
  fi
  if printf '%s\n' "$profiles" | grep -q 'altschool-core-local'; then
    ok "auth profile altschool-core-local"
  else
    warn_msg "no altschool-core-local"
  fi
  if printf '%s\n' "$profiles" | grep -q 'altschool-core-diagnosis'; then
    ok "auth profile altschool-core-diagnosis"
  else
    warn_msg "no altschool-core-diagnosis (confirm Core production origin before creating)"
  fi
fi

check_port() {
  local port="$1" label="$2"
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn 2>/dev/null | grep -qE ":${port}[[:space:]]"; then
      ok "$label port $port is listening"
      return
    fi
  elif command -v lsof >/dev/null 2>&1; then
    if lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      ok "$label port $port is listening"
      return
    fi
  fi
  warn_msg "$label port $port is not listening (needed only for local/preview)"
}

check_port 8006 "student"
check_port 8007 "core"
check_port 443 "caddy/https"

if [[ -s "$HOME/.altschool-preview.json" ]]; then
  ok "preview URL file exists $HOME/.altschool-preview.json (contents not printed)"
else
  warn_msg "no $HOME/.altschool-preview.json (ok unless env=preview)"
fi

art="$HOME/.altschool/portal-qa"
mkdir -p "$art"
ok "artifact root $art"

if [[ "$fail" -ne 0 ]]; then
  note "preflight failed"
  exit 1
fi
note "preflight passed (warnings=$warn_count)"
exit 0
