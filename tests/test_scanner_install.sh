#!/usr/bin/env bash
# Exercise command installation without package installs or host mutations.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/.local/bin" "$fixture/repo/scripts"
cp "$root/scripts/scan_repo.sh" "$fixture/repo/scripts/"
export DOTFILES_DIR="$root" SCANNER_INSTALL_FIXTURE="$fixture"
# HOME is supplied only to the child fixture, never changed in the host shell.
{
  cat <<'SETUP'
set -eu
create_symlink() { ln -sf "$1" "$2"; }
mkdir -p "$HOME/bin"
printf 'preserve me\n' > "$HOME/bin/test_user.sh"
ln -s "$DOTFILES_DIR/scripts/test_scan_repo.sh" "$HOME/bin/test_scan_repo.sh"
ln -s "$DOTFILES_DIR/scripts/worm_guard_run.sh" "$HOME/bin/worm_guard_run.sh"
ln -s "$DOTFILES_DIR/scripts/worm_guard_watch.sh" "$HOME/bin/worm_guard_watch.sh"
ln -s "$DOTFILES_DIR/scripts/watch_remotes.sh" "$HOME/bin/watch_remotes.sh"
ln -s "$DOTFILES_DIR/scripts/install_cloud_dotfiles.sh" "$HOME/bin/install_cloud_dotfiles.sh"
ln -s "$DOTFILES_DIR/scripts/scan_repo.sh" "$HOME/bin/scan-repo.sh"
ln -sf /some/other/checkout/helper.py "$HOME/bin/other-helper"
SETUP
  sed -n '/^PUBLIC_SCRIPTS=(/,/^# Touch ID/{ /^# Touch ID/!p; }' "$root/install.sh"
  cat <<'CHECK'
[ ! -L "$HOME/bin/test_scan_repo.sh" ]
[ ! -L "$HOME/bin/worm_guard_run.sh" ]
[ ! -L "$HOME/bin/worm_guard_watch.sh" ]
[ ! -L "$HOME/bin/watch_remotes.sh" ]
[ ! -L "$HOME/bin/install_cloud_dotfiles.sh" ]
[ ! -L "$HOME/bin/scan-repo.sh" ]
[ -f "$HOME/bin/test_user.sh" ]
[ -L "$HOME/bin/other-helper" ]
for name in scan_repo.sh scan_remote.sh; do
  [ "$(readlink "$HOME/bin/$name")" = "$DOTFILES_DIR/scripts/$name" ]
done
[ ! -e "$HOME/Library/LaunchAgents" ]
CHECK
} > "$fixture/mac.sh"
env HOME="$fixture" /bin/bash "$fixture/mac.sh"
# Reinstallation is safe and preserves custom commands.
env HOME="$fixture" /bin/bash "$fixture/mac.sh"
{
  printf '%s\n' 'set -eu' 'link_path() { ln -sf "$1" "$2"; }'
  sed -n '/^for script_name in scan_repo.sh scan_remote.sh;/,/^done/p' "$root/scripts/install_cloud_dotfiles.sh"
  cat <<'CHECK'
for name in scan_repo.sh scan_remote.sh; do
  [ "$(readlink "$HOME/.local/bin/$name")" = "$DOTFILES_DIR/scripts/$name" ]
done
[ ! -e "$HOME/.local/bin/worm_guard_watch.sh" ]
CHECK
} > "$fixture/cloud.sh"
env HOME="$fixture" /bin/bash "$fixture/cloud.sh"
[ -z "$(git config --file "$root/git/.gitconfig" --get core.hooksPath || true)" ]
for name in pre-commit pre-push post-checkout post-merge; do
  [ ! -e "$root/git/hooks/$name" ]
done
printf '%s\n' 'PASS: public commands installed; retired/helper links removed; user files preserved; cloud scanners installed without scheduling or global hooks.'
