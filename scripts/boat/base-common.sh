#!/usr/bin/env bash
# Shared setup for <project>-base build machines. Runs as `user` over boat ssh.
set -euo pipefail

# Faster apt from boat machines (boat docs: CI guide, "Fast apt-get").
sudo sed -i 's#http://[a-z.]*archive.ubuntu.com#http://fr.archive.ubuntu.com#g' /etc/apt/sources.list.d/ubuntu.sources

# Lines that must run before ~/.bashrc returns early for non-interactive shells,
# so `boat exec`, `boat ssh <id> cmd` and `boat run` see them too.
# ~/.cache is not saved in snapshots, so Playwright browsers live in ~/.local/share.
if ! grep -q 'boat-base: early env' ~/.bashrc; then
  sed -i '1i # boat-base: early env (keep at the top; non-interactive shells stop reading below)\
export PLAYWRIGHT_BROWSERS_PATH=$HOME/.local/share/ms-playwright\
export BUN_INSTALL=$HOME/.bun\
case ":$PATH:" in *":$HOME/.bun/bin:"*) ;; *) export PATH=$HOME/.bun/bin:$HOME/.local/bin:$PATH ;; esac' ~/.bashrc
fi
export PLAYWRIGHT_BROWSERS_PATH=$HOME/.local/share/ms-playwright
export BUN_INSTALL=$HOME/.bun
export PATH=$HOME/.bun/bin:$HOME/.local/bin:$PATH

# Clone a repo from a git bundle at a fixed path, with origin/* refs, then point origin at GitHub.
# usage: clone_from_bundle <bundle> <dest> <github ssh url>
clone_from_bundle() {
  local bundle=$1 dest=$2 url=$3
  mkdir -p "$dest"
  cd "$dest"
  if [ ! -d .git ]; then
    git init -q -b main
    git fetch -q "$bundle" 'refs/remotes/origin/*:refs/remotes/origin/*' 'refs/tags/*:refs/tags/*'
    git remote add origin "$url"
    git checkout -q -f -B main origin/main
    git branch -q -u origin/main main
  fi
  git log -1 --format='HEAD %h %cs %s'
}
