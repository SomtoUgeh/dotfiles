#!/usr/bin/env bash
# CLIs that Somto's skills call, at the versions julds uses (7 Nov 2026).
# Runs as `user` on a project VM. Idempotent. Sign-ins are separate:
#   aside login --email <account>   (confirm the code in Aside on the Mac: Settings > Account > Devices)
#   aside host use <Mac host from `aside host list`>   (send browser tasks to the Mac, as on julds)
#   op                     (needs the 1Password service account token; not installed here)
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
mkdir -p "$HOME/.local/bin"

echo "== apt: shellcheck, fd, bat"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq shellcheck fd-find bat >/dev/null
ln -sfn /usr/bin/fdfind "$HOME/.local/bin/fd"
ln -sfn /usr/bin/batcat "$HOME/.local/bin/bat"

echo "== npm globals in ~/.local (no sudo)"
npm install -g --prefix "$HOME/.local" --no-fund --no-audit --loglevel=error \
  agent-browser@0.39.2 wrangler@4.152.0 cf@1.0.0-beta.21
# agent-browser's own Chrome (~400 MB in ~/.agent-browser).
agent-browser install >/dev/null 2>&1 || agent-browser install

echo "== Aside CLI"
command -v aside >/dev/null || curl -fsSL https://releases.aside.com/install.sh | bash

for c in shellcheck fd bat agent-browser wrangler cf aside; do
  printf '%-14s %s\n' "$c" "$("$c" --version 2>/dev/null | head -1 || echo missing)"
done
