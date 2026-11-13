#!/usr/bin/env bash
# Runs the two link functions of install.sh against a temporary home. The
# rest of install.sh sets up a Mac and is not run here.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME=$fixture/home
unset SKILLHUB_HOME
AGENTS_DIR=$fixture/dotfiles/agents
GREEN='' YELLOW='' NC=''
mkdir -p "$HOME/.agents" "$AGENTS_DIR/skills/alpha"

functions=$(sed -n '/^create_symlink() {$/,/^}$/p; /^link_skill_folder() {$/,/^}$/p' "$root/install.sh")
grep -q '^create_symlink() {$' <<<"$functions"
grep -q '^link_skill_folder() {$' <<<"$functions"
eval "$functions"

target=$HOME/.agents/skills
is_shared_link() { [ -L "$target" ] && [ "$(readlink "$target")" = "$AGENTS_DIR/skills" ]; }

# No folder yet: the link to the shared skills.
link_skill_folder "$target" >/dev/null
is_shared_link

# No Skillhub, and a tool made the folder first: the folder moves to a backup, and the link takes its place.
rm "$target"
mkdir -p "$target/own"
link_skill_folder "$target" >/dev/null
is_shared_link
[ -d "$(find "$HOME/.agents" -maxdepth 1 -name 'skills.backup.*')/own" ]

# Skillhub manages the machine: a real folder stays, and no backup is made.
rm -r "$HOME/.agents"
mkdir -p "$target/beta" "$HOME/.skillhub"
echo '{}' >"$HOME/.skillhub/managed.json"
link_skill_folder "$target" | grep -q 'kept as it is'
[ -d "$target/beta" ] && [ ! -L "$target" ]
[ -z "$(find "$HOME/.agents" -maxdepth 1 -name 'skills.backup.*')" ]

# Skillhub manages the machine, and the folder is still a link: the link stays for `skillhub adopt`.
rm -r "$target"
link_skill_folder "$target" >/dev/null
is_shared_link

# The ledger can be in another place.
rm "$target"
mkdir -p "$target/beta" "$fixture/state"
mv "$HOME/.skillhub/managed.json" "$fixture/state/"
SKILLHUB_HOME=$fixture/state link_skill_folder "$target" | grep -q 'kept as it is'
[ -d "$target/beta" ] && [ ! -L "$target" ]
echo "test_link_skill_folder: ok"
