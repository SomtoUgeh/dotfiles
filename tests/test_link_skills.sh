#!/usr/bin/env bash
# Runs scripts/link_skills.sh and scripts/retire_skillhub.sh against a
# temporary home. skillhub and trash are stubs: no network, no real Trash.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME=$fixture/home
unset SKILLHUB_HOME
A=$fixture/dotfiles/agents
mkdir -p "$HOME" "$A/skills/alpha" "$fixture/p3-stack/skills/p3one" "$fixture/p3-stack/skills/p3two" "$fixture/elsewhere/own"
ln -s ../../../p3-stack/skills/p3one "$A/skills/p3one"
ln -s ../../../p3-stack/skills/p3two "$A/skills/p3two"

link() { bash "$root/scripts/link_skills.sh" "$A" "$@"; }
is_link_to() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }
listing() { for x in "$1"/*; do echo "$x $(readlink "$x" || true)"; done; }
t=$HOME/.claude/skills

# A new folder gets only the p3-stack skills.
link "$t" | grep -q 'has 2 skills on disk'
is_link_to "$t/p3one" "$A/skills/p3one"
is_link_to "$t/p3two" "$A/skills/p3two"
[ ! -e "$t/alpha" ]

# The old link of the whole folder becomes a real folder.
rm -r "$t"
ln -s "$A/skills" "$t"
link "$t" >/dev/null
[ -d "$t" ] && [ ! -L "$t" ]
is_link_to "$t/p3one" "$A/skills/p3one"

# Links to shared skills that are not on disk go, and so do broken links.
# Real folders and links to other places stay.
ln -s "$A/skills/alpha" "$t/alpha"
ln -s "$fixture/gone" "$t/broken"
mkdir "$t/aside-browser"
ln -s "$fixture/elsewhere/own" "$t/own"
link "$t" >/dev/null
[ ! -L "$t/alpha" ] && [ ! -L "$t/broken" ]
[ -d "$t/aside-browser" ] && [ ! -L "$t/aside-browser" ]
is_link_to "$t/own" "$fixture/elsewhere/own"

# A second run changes nothing.
before=$(listing "$t")
link "$t" >/dev/null
[ "$before" = "$(listing "$t")" ]

# A relative agents folder still makes absolute links.
rm "$t/p3one"
(cd "$fixture/dotfiles" && bash "$root/scripts/link_skills.sh" agents "$t" >/dev/null)
is_link_to "$t/p3one" "$A/skills/p3one"
[ -e "$t/p3one" ]

# A folder that links to another place is left as it is.
ln -s "$fixture/elsewhere" "$HOME/other"
link "$HOME/other" 2>&1 | grep -q 'left as it is'
is_link_to "$HOME/other" "$fixture/elsewhere"

# Retiring Skillhub: the uninstall runs, the state folder and a pushed
# checkout go, and a checkout with work that is not pushed stays.
stubs=$fixture/stubs
mkdir -p "$stubs" "$HOME/.skillhub" "$HOME/.bun/bin"
echo '{}' >"$HOME/.skillhub/managed.json"
printf '%s\n' '#!/bin/sh' 'echo "$*" >>"$HOME/skillhub.calls"' >"$stubs/skillhub"
printf '%s\n' '#!/bin/sh' 'rm -rf "$1"' >"$stubs/trash"
chmod +x "$stubs/skillhub" "$stubs/trash"
ln -s "$stubs/skillhub" "$HOME/.bun/bin/skillhub"
g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
git init -q --bare "$fixture/remote.git"
g clone -q "$fixture/remote.git" "$HOME/code/personal/skillhub" 2>/dev/null
g -C "$HOME/code/personal/skillhub" commit -q --allow-empty -m one
g -C "$HOME/code/personal/skillhub" push -q origin HEAD 2>/dev/null
g clone -q "$fixture/remote.git" "$HOME/.t3/projects/skillset" 2>/dev/null
g -C "$HOME/.t3/projects/skillset" commit -q --allow-empty -m unpushed

retire() { PATH="$stubs:$PATH" bash "$root/scripts/retire_skillhub.sh"; }
retire >"$fixture/out" 2>"$fixture/err"
[ "$(cat "$HOME/skillhub.calls")" = "uninstall --yes" ]
[ ! -e "$HOME/.skillhub" ] && [ ! -L "$HOME/.bun/bin/skillhub" ]
[ ! -e "$HOME/code/personal/skillhub" ]
[ -d "$HOME/.t3/projects/skillset/.git" ]
grep -q 'skillset has work that is not pushed; left in place' "$fixture/err"

# A second run is quiet and calls nothing.
rm "$HOME/skillhub.calls"
g -C "$HOME/.t3/projects/skillset" push -q origin HEAD 2>/dev/null
retire >"$fixture/out" 2>"$fixture/err"
[ ! -e "$HOME/skillhub.calls" ]
[ ! -e "$HOME/.t3/projects/skillset" ]
retire >"$fixture/out" 2>"$fixture/err"
[ ! -s "$fixture/out" ] && [ ! -s "$fixture/err" ]
echo "test_link_skills: ok"
