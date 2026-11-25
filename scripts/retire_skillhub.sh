#!/usr/bin/env bash
# Remove Skillhub from this machine. Skills now come from the Executor app
# `skills` (services/skills-mcp) and scripts/link_skills.sh. Idempotent and
# quiet when Skillhub is gone; scripts/boat/link-agent-config.sh runs it on
# each project VM.
set -euo pipefail
state=${SKILLHUB_HOME:-$HOME/.skillhub}

remove() { # <path>: to the Trash where there is one
  if command -v trash >/dev/null; then trash "$1"; else rm -rf "$1"; fi
}

# Skillhub takes back what it put in place: its skill links, its backups, and
# its hooks in the Claude, Codex, Cursor, OpenCode and Grok configurations.
if [ -f "$state/managed.json" ] && command -v skillhub >/dev/null; then
  if ! skillhub uninstall --yes >/dev/null; then
    echo "retire-skillhub: skillhub uninstall failed; Skillhub is left in place" >&2
    exit 1
  fi
  echo "retire-skillhub: Skillhub links and hooks removed"
fi

units=$HOME/.config/systemd/user
if [ -f "$units/skillhub-sync.timer" ]; then
  systemctl --user disable --now skillhub-sync.timer >/dev/null 2>&1 || true
  rm -f "$units/skillhub-sync.timer" "$units/skillhub-sync.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  echo "retire-skillhub: skillhub-sync.timer removed"
fi

# The command is a `bun link` of the checkout.
for link in "$HOME/.bun/bin/skillhub" "$HOME/.bun/install/global/node_modules/skillhub"; do
  if [ -L "$link" ]; then rm "$link"; fi
done

if [ -d "$state" ]; then
  remove "$state"
  echo "retire-skillhub: $state removed"
fi

for repo in "$HOME/code/personal/skillhub" "$HOME/.t3/projects/skillset"; do
  [ -d "$repo/.git" ] || continue
  if [ -n "$(git -C "$repo" status --porcelain)" ] || [ -n "$(git -C "$repo" log --branches --not --remotes --oneline)" ]; then
    echo "retire-skillhub: $repo has work that is not pushed; left in place" >&2
    continue
  fi
  remove "$repo"
  echo "retire-skillhub: $repo removed"
done
