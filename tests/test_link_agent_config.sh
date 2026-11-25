#!/usr/bin/env bash
# Runs the real link-agent-config.sh against a temporary home. git, uv,
# systemctl, trash and skillhub are stubs: no network, no sign-in, no user units.
set -euo pipefail
if [ "$(uname)" != Linux ] && [ "${FORCE_LINUX_TEST:-}" != 1 ]; then
  echo "skipped: link-agent-config.sh runs on Linux project VMs only"
  exit 0
fi
root=$(cd "$(dirname "$0")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
home=$fixture/home
stubs=$fixture/stubs
dotfiles=$home/code/personal/dotfiles
skills=$dotfiles/agents/skills
claude=$home/.claude/skills
units=$home/.config/systemd/user

mkdir -p "$stubs" "$dotfiles/.git" "$dotfiles/scripts/boat" "$dotfiles/agents/shared/hooks" \
  "$home/code/personal/p3-stack/.git" "$home/code/personal/p3-stack/skills/p3one" \
  "$skills/alpha" "$skills/boat" "$claude/boat" "$claude/synced" "$home/elsewhere/gamma"
ln -s ../../../p3-stack/skills/p3one "$skills/p3one"
cp "$root/scripts/boat/link-agent-config.sh" "$dotfiles/scripts/boat/"
cp "$root/scripts/link_skills.sh" "$root/scripts/retire_skillhub.sh" "$root/scripts/skill-fetch" "$dotfiles/scripts/"
cp "$root/agents/shared/hooks/skills_index.sh" "$dotfiles/agents/shared/hooks/"
# git status and git log print nothing: a skillhub checkout counts as pushed.
printf '%s\n' '#!/bin/sh' 'case "$*" in *rev-parse*) echo abc1234 ;; esac' >"$stubs/git"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$stubs/uv"
cp "$stubs/uv" "$stubs/systemctl"
printf '%s\n' '#!/bin/sh' 'rm -rf "$1"' >"$stubs/trash"
printf '%s\n' '#!/bin/sh' 'echo "$*" >>"$HOME/skillhub.calls"' 'exit "$(cat "$HOME/skillhub.exit" 2>/dev/null || echo 0)"' >"$fixture/skillhub"
chmod +x "$stubs"/* "$fixture/skillhub"

run() { env -i HOME="$home" PATH="$stubs:/usr/bin:/bin" bash "$dotfiles/scripts/boat/link-agent-config.sh" >"$fixture/out" 2>"$fixture/err"; }
is_link_to() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }
skillhub_vm() {
  mkdir -p "$home/.skillhub" "$home/.bun/bin" "$units" "$home/code/personal/skillhub/.git"
  echo '{}' >"$home/.skillhub/managed.json"
  ln -sfn "$fixture/skillhub" "$home/.bun/bin/skillhub"
  touch "$units/skillhub-sync.timer" "$units/skillhub-sync.service"
}

# A new VM: only the p3-stack skills are on disk, and boat's own folders stay.
run
is_link_to "$claude/p3one" "$skills/p3one"
is_link_to "$home/.agents/skills/p3one" "$skills/p3one"
[ ! -e "$claude/alpha" ] && [ ! -e "$claude/boat/p3one" ]
[ -d "$claude/boat" ] && [ ! -L "$claude/boat" ] && [ -d "$claude/synced" ]
is_link_to "$home/.local/bin/skill-fetch" "$dotfiles/scripts/skill-fetch"
is_link_to "$home/.claude/hooks/skills-index.sh" "$dotfiles/agents/shared/hooks/skills_index.sh"
grep -q 'has 1 skills on disk; the others load through Executor, dotfiles abc1234' "$fixture/out"
[ ! -e "$home/skillhub.calls" ] && [ ! -s "$fixture/err" ]

# A VM that Skillhub managed: Skillhub takes back its links and hooks, its
# timer, command, state and checkout go, and the old links of every skill go.
skillhub_vm
mkdir -p "$home/.config/opencode"
ln -s "$skills/alpha" "$claude/alpha"
ln -s "$home/elsewhere/gamma" "$claude/gamma"
run
[ "$(cat "$home/skillhub.calls")" = "uninstall --yes" ]
[ ! -e "$home/.skillhub" ] && [ ! -e "$home/code/personal/skillhub" ] && [ ! -L "$home/.bun/bin/skillhub" ]
[ ! -e "$units/skillhub-sync.timer" ] && [ ! -e "$units/skillhub-sync.service" ]
[ ! -L "$claude/alpha" ]
is_link_to "$claude/gamma" "$home/elsewhere/gamma"
is_link_to "$home/.config/opencode/skills/p3one" "$skills/p3one"

# A failed uninstall leaves Skillhub in place, and the skills are still linked.
rm "$home/skillhub.calls"
skillhub_vm
echo 1 >"$home/skillhub.exit"
ln -s "$skills/alpha" "$claude/alpha"
run
grep -q 'Skillhub was not fully removed' "$fixture/err"
[ -f "$home/.skillhub/managed.json" ]
[ ! -L "$claude/alpha" ] && is_link_to "$claude/p3one" "$skills/p3one"
[ -x "$home/.local/bin/link-agent-config" ]
echo "test_link_agent_config: ok"
