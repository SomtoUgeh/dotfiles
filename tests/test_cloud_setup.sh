#!/usr/bin/env bash
# Inert extracted blocks and a temporary signing key; no SSH/network/installers.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
key="$fixture/key"
ssh-keygen -q -t ed25519 -N '' -f "$key"
personal_config="$fixture/personal"
allowed="$fixture/allowed"
email=fixture@example.invalid
timestamp=test
git config -f "$personal_config" custom.keep preserved
git config -f "$personal_config" gpg.ssh.program /Applications/obsolete
# Only extract the pure config-writing block, never the installer entrypoint.
sed -n '/^  # Change only the cloud/,/^  chmod 600 "\$personal_config"/p' "$root/scripts/install_cloud_dotfiles.sh" > "$fixture/config.sh"
. "$fixture/config.sh"
[ "$(git config -f "$personal_config" custom.keep)" = preserved ]
[ "$(git config -f "$personal_config" gpg.ssh.program)" = ssh-keygen ]
[ -f "$personal_config.backup.test" ]
printf '%s %s\n' "$email" "$(cat "$key.pub")" > "$allowed"
git init -q "$fixture/repo"
git -C "$fixture/repo" config include.path "$personal_config"
git -C "$fixture/repo" commit --allow-empty -qm fixture
git -C "$fixture/repo" verify-commit HEAD >/dev/null 2>&1
# Execute the real setup function and its direct caller in child shells.
# GitHub is mocked; malformed config/keygen/permission failures must stop setup.
sed -n '/^add_github_ssh_key()/,/^install_pinned_repository()/ { /^install_pinned_repository()/!p; }' "$root/scripts/install_cloud_dotfiles.sh" > "$fixture/functions.sh"
{
  printf '%s\n' 'set -euo pipefail' 'timestamp=test' 'DOTFILES_DIR="$1"' '. "$2"' 'gh() { return 1; }'
  cat <<'SH'
case "$3" in
  keygen) ssh-keygen() { return 23; } ;;
  chmod) chmod() { return 24; } ;;
esac
SH
  sed -n '/^# Call directly/,/^setup_personal_github_ssh/p' "$root/scripts/install_cloud_dotfiles.sh"
  printf '%s\n' 'echo SETUP_COMPLETED'
} > "$fixture/setup.sh"
for failure in malformed keygen chmod; do
  test_home="$fixture/$failure"
  mkdir -p "$test_home/.ssh"
  if [ "$failure" != keygen ]; then
    cp "$key" "$test_home/.ssh/id_ed25519_personal"
    cp "$key.pub" "$test_home/.ssh/id_ed25519_personal.pub"
  fi
  if [ "$failure" = malformed ]; then
    printf '[invalid\n' > "$test_home/.gitconfig-personal"
  fi
  status=0
  env HOME="$test_home" bash "$fixture/setup.sh" "$root" "$fixture/functions.sh" "$failure" > "$fixture/$failure.log" 2>&1 || status=$?
  [ "$status" -ne 0 ]
  ! grep -q SETUP_COMPLETED "$fixture/$failure.log"
done
# Optional GitHub upload failure does not invalidate successful local setup.
sed 's/gh() { return 1; }/gh() { if [ "$1" = auth ] || [ "$1" = config ]; then return 0; else return 1; fi; }/' "$fixture/setup.sh" > "$fixture/upload.sh"
mkdir -p "$fixture/upload/.ssh"
cp "$key" "$fixture/upload/.ssh/id_ed25519_personal"
cp "$key.pub" "$fixture/upload/.ssh/id_ed25519_personal.pub"
env HOME="$fixture/upload" bash "$fixture/upload.sh" "$root" "$fixture/functions.sh" upload > "$fixture/upload.log" 2>&1
grep -q SETUP_COMPLETED "$fixture/upload.log"
grep -q 'Could not upload the authentication key' "$fixture/upload.log"
# Clone block: a fake gh records arguments, all app execution would fail.
awk '/^repository="\$1"/{copy=1} copy && /^REMOTE$/{exit} copy{print}' "$root/scripts/setup_altschool_cloud.sh" > "$fixture/clone.sh"
mkdir -p "$fixture/home/code/TalentQL"
cat > "$fixture/clone-run.sh" <<'SH'
set -eu
export HOME="$1"
log="$2"
gh() { printf '%s\n' "$@" > "$log"; mkdir -p "$4/.git"; }
bun() { exit 99; }
bunx() { exit 99; }
script="$3"
set -- owner/repository
. "$script"
SH
bash "$fixture/clone-run.sh" "$fixture/home" "$fixture/args" "$fixture/clone.sh"
grep -qx -- --depth=1 "$fixture/args"
rm "$fixture/args"
bash "$fixture/clone-run.sh" "$fixture/home" "$fixture/args" "$fixture/clone.sh"
[ ! -e "$fixture/args" ]
# Missing Node must reach the toolchain summary rather than abort.
{
  printf '%s\n' 'set -euo pipefail' 'failures=0' 'TOOLCHAIN_ONLY=1' 'ok() { :; }' 'fail() { failures=$((failures+1)); }' 'node() { return 127; }' 'bun() { echo fixture; }' 'grok() { echo fixture; }' 'opencode2() { echo fixture; }'
  sed -n '/^if node_version=/,/^if systemctl/{ /^if systemctl/!p; }' "$root/scripts/verify_altschool_cloud.sh"
} > "$fixture/verify.sh"
status=0
bash "$fixture/verify.sh" > "$fixture/result" || status=$?
[ "$status" = 1 ]
grep -q 'Toolchain verification finished with 1 failure' "$fixture/result"
# OpenCode 2 cloud links include hook plugins and agents; V1 npm leftovers are removed.
opencode_home="$fixture/opencode-home"
mkdir -p "$opencode_home/.config/opencode/node_modules/left" \
  "$opencode_home/.config/opencode/plugin"
printf '%s\n' '{"private":true}' > "$opencode_home/.config/opencode/package.json"
printf '%s\n' 'node_modules' > "$opencode_home/.config/opencode/.gitignore"
ln -s /missing/plugins "$opencode_home/.config/opencode/plugins"
{
  printf '%s\n' 'set -eu' 'DOTFILES_DIR="$1"' 'timestamp=test'
  sed -n '/^link_path() {/,/^}$/p' "$root/scripts/install_cloud_dotfiles.sh"
  sed -n '/^# OpenCode 2 config, agents, commands, skills, and hook plugins\./,/^done$/p' "$root/scripts/install_cloud_dotfiles.sh"
} > "$fixture/opencode-links.sh"
env HOME="$opencode_home" bash "$fixture/opencode-links.sh" "$root"
[ ! -e "$opencode_home/.config/opencode/node_modules" ]
[ ! -e "$opencode_home/.config/opencode/package.json" ]
[ ! -e "$opencode_home/.config/opencode/.gitignore" ]
[ ! -e "$opencode_home/.config/opencode/plugin" ]
[ -d "$opencode_home/.config/opencode/plugin.backup.test" ]
[ -d "$opencode_home/.config/opencode/plugins" ]
[ ! -L "$opencode_home/.config/opencode/plugins" ]
[ "$(readlink "$opencode_home/.config/opencode/plugins/git-guard.js")" = "$root/agents/opencode/plugins/git-guard.js" ]
[ "$(readlink "$opencode_home/.config/opencode/plugins/shaping-ripple.js")" = "$root/agents/opencode/plugins/shaping-ripple.js" ]
[ "$(readlink "$opencode_home/.config/opencode/agents")" = "$root/agents/opencode/agents" ]

printf '%s\n' 'PASS: Linux signing works and custom config survives; clone is shallow and existing checkout untouched; missing Node reports a summary; OpenCode plugins and agents are linked.'
