#!/usr/bin/env bash
# Runs the real link-agent-config.sh against a temporary home. git, uv,
# systemctl and skillhub are stubs: no network, no sign-in, no user units.
set -euo pipefail
if [ "$(uname)" != Linux ]; then
  echo "skipped: link-agent-config.sh runs on Linux project VMs only"
  exit 0
fi
root=$(cd "$(dirname "$0")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
home=$fixture/home
stubs=$fixture/stubs
dotfiles=$home/code/personal/dotfiles
claude=$home/.claude/skills
ledger=$home/.skillhub/managed.json

mkdir -p "$stubs" "$dotfiles/.git" "$home/code/personal/p3-stack/.git" "$dotfiles/scripts/boat" \
  "$dotfiles/agents/skills/alpha" "$dotfiles/agents/skills/beta" "$dotfiles/agents/skills/boat" \
  "$claude/boat" "$claude/synced" "$home/elsewhere/gamma"
cp "$root/scripts/boat/link-agent-config.sh" "$dotfiles/scripts/boat/"
printf '%s\n' '#!/bin/sh' 'case "$*" in *rev-parse*) echo abc1234 ;; esac' >"$stubs/git"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$stubs/uv"
cp "$stubs/uv" "$stubs/systemctl"
# skillhub.exit.<subcommand> makes one subcommand fail.
printf '%s\n' '#!/bin/sh' 'echo "$*" >>"$HOME/skillhub.calls"' 'exit "$(cat "$HOME/skillhub.exit.$1" 2>/dev/null || echo 0)"' >"$fixture/skillhub"
printf '%s\n' '#!/bin/sh' 'echo "$PWD $*" >>"$HOME/bun.calls"' 'exit "$(cat "$HOME/bun.exit" 2>/dev/null || echo 0)"' >"$stubs/bun"
chmod +x "$stubs"/* "$fixture/skillhub"
ln -s "$(command -v jq)" "$stubs/jq"

run() { env -i HOME="$home" PATH="$stubs:/usr/bin:/bin" bash "$root/scripts/boat/link-agent-config.sh" >"$fixture/out" 2>"$fixture/err"; }
is_link_to() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }
write_ledger() { mkdir -p "$(dirname "$ledger")" && printf '%s\n' "$1" >"$ledger"; }
owns_beta='{"deviceId":"d","folders":{"'$claude'":{"entries":{"beta":"'$dotfiles/agents/skills/beta'"}}}}'

# No Skillhub: every shared skill is linked, and boat's own folders stay.
run
is_link_to "$claude/alpha" "$dotfiles/agents/skills/alpha"
is_link_to "$claude/beta" "$dotfiles/agents/skills/beta"
is_link_to "$home/.agents/skills" "$dotfiles/agents/skills"
[ -d "$claude/boat" ] && [ ! -L "$claude/boat" ] && [ -d "$claude/synced" ]
grep -q '2 skills linked, dotfiles abc1234' "$fixture/out"
[ ! -e "$home/skillhub.calls" ]

# Skillhub manages the VM: the links of this script go, the link that
# Skillhub owns and a link of the user stay, and Skillhub adopts the neutral
# path, which is still one link to every skill. A sync follows in each case:
# an adopt that changes nothing does not sync.
write_ledger "$owns_beta"
ln -s "$fixture/skillhub" "$stubs/skillhub"
ln -s "$home/elsewhere/gamma" "$claude/gamma"
run
[ ! -e "$claude/alpha" ] && [ ! -L "$claude/alpha" ]
is_link_to "$claude/beta" "$dotfiles/agents/skills/beta"
is_link_to "$claude/gamma" "$home/elsewhere/gamma"
[ -d "$claude/boat" ] && [ -d "$claude/synced" ]
grep -q 'skills left to Skillhub (1 links of this script removed)' "$fixture/out"
[ "$(cat "$home/skillhub.calls")" = "mode download
adopt $home/.agents/skills --yes
sync" ]
# No skillhub checkout: nothing is installed.
[ ! -e "$home/bun.calls" ]

# An adopt and a sync that fail do not stop the script.
echo 1 >"$home/skillhub.exit.adopt"
echo 1 >"$home/skillhub.exit.sync"
run
grep -q 'skillhub adopt of ~/.agents/skills did not complete' "$fixture/err"
grep -q 'skillhub sync failed' "$fixture/err"
[ -x "$home/.local/bin/link-agent-config" ]

# A link to another place becomes the shared link again before the adopt.
rm "$home/.agents/skills" "$home/skillhub.calls"
ln -s "$home/elsewhere" "$home/.agents/skills"
run
is_link_to "$home/.agents/skills" "$dotfiles/agents/skills"
[ "$(sed -n 2p "$home/skillhub.calls")" = "adopt $home/.agents/skills --yes" ]
rm "$home"/.agents/skills.backup.*

# After the adopt the neutral path is a real folder: it stays, and Skillhub syncs.
rm "$home/.agents/skills" "$home/skillhub.calls" "$home/skillhub.exit.adopt" "$home/skillhub.exit.sync"
mkdir "$home/.agents/skills"
run
[ -d "$home/.agents/skills" ] && [ ! -L "$home/.agents/skills" ]
! ls "$home/.agents" | grep -q backup
grep -q '(0 links of this script removed)' "$fixture/out"
[ "$(cat "$home/skillhub.calls")" = "mode download
sync" ]

# A second run changes nothing, and a failed sync does not stop the script.
echo 1 >"$home/skillhub.exit.sync"
run
is_link_to "$claude/beta" "$dotfiles/agents/skills/beta"
grep -q '(0 links of this script removed)' "$fixture/out"
grep -q 'skillhub sync failed' "$fixture/err"
[ -x "$home/.local/bin/link-agent-config" ]

# A machine that cannot be put in download mode is not synced: a sync in
# link mode would link the tools to the dotfiles copy of the skills.
rm "$home/skillhub.calls" "$home/skillhub.exit.sync"
echo 1 >"$home/skillhub.exit.mode"
run
grep -q 'skillhub mode download failed' "$fixture/err"
[ "$(cat "$home/skillhub.calls")" = "mode download" ]
rm "$home/skillhub.exit.mode" "$home/skillhub.calls"

# A skillhub checkout is pulled and installed before the sync. A failed
# install is named, and the sync still runs with the command that is there.
mkdir -p "$home/code/personal/skillhub/.git"
run
grep -q "^$home/code/personal/skillhub install --silent --frozen-lockfile --production$" "$home/bun.calls"
echo 1 >"$home/bun.exit"
run
grep -q 'bun install in ~/code/personal/skillhub failed' "$fixture/err"
[ "$(tail -n 1 "$home/skillhub.calls")" = sync ]
rm -r "$home/code/personal/skillhub" "$home/bun.exit" "$home/bun.calls" "$home/skillhub.calls"

# No skillhub command: the links still go, and the output names the gap.
rm "$stubs/skillhub"
ln -s "$dotfiles/agents/skills/alpha" "$claude/alpha"
run
[ ! -L "$claude/alpha" ]
grep -q 'skillhub command is not on the path' "$fixture/err"
[ ! -e "$home/skillhub.calls" ]

# A damaged ledger: nothing is removed.
ln -s "$dotfiles/agents/skills/alpha" "$claude/alpha"
write_ledger '{not json'
run
is_link_to "$claude/alpha" "$dotfiles/agents/skills/alpha"
is_link_to "$claude/beta" "$dotfiles/agents/skills/beta"
grep -q 'cannot read' "$fixture/err"
grep -q 'skills left as they are' "$fixture/out"

# After `skillhub uninstall --yes` the ledger is gone, and every skill is linked again.
rm "$ledger" "$claude/alpha" "$claude/gamma"
rmdir "$home/.agents/skills"
run
is_link_to "$claude/alpha" "$dotfiles/agents/skills/alpha"
is_link_to "$home/.agents/skills" "$dotfiles/agents/skills"
grep -q '2 skills linked' "$fixture/out"
echo "test_link_agent_config: ok"
