#!/usr/bin/env bash
# CLIs that Somto's skills call, at the versions julds uses (7 Nov 2026).
# Runs as `user` on a project VM. Idempotent. Sign-ins are separate:
#   aside login --email <account>   (confirm the code in Aside on the Mac: Settings > Account > Devices)
#   aside host use <Mac host from `aside host list`>   (send browser tasks to the Mac, as on julds)
#   op                     (token: boat env set-file <env> .config/op/service-account-token; loads in login shells)
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

echo "== 1Password CLI (op), from 1Password's apt repo as on julds"
if ! command -v op >/dev/null; then
  curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
    sudo gpg --dearmor --yes --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' |
    sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
    sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
  curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
    sudo gpg --dearmor --yes --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq 1password-cli >/dev/null
fi
# The token is a boat environment secret file (never in a snapshot):
#   boat env set-file <env> .config/op/service-account-token
# boat writes the file with mode 644 under a 755 folder at each start, and op
# refuses a folder that others can read, so tighten both before the export.
grep -q OP_SERVICE_ACCOUNT_TOKEN "$HOME/.profile" || cat >>"$HOME/.profile" <<'OP'
if [ -r "$HOME/.config/op/service-account-token" ]; then
  chmod 700 "$HOME/.config/op"; chmod 600 "$HOME/.config/op/service-account-token"
  export OP_SERVICE_ACCOUNT_TOKEN="$(cat "$HOME/.config/op/service-account-token")"
fi
OP

echo "== Aside CLI"
command -v aside >/dev/null || curl -fsSL https://releases.aside.com/install.sh | bash

for c in shellcheck fd bat agent-browser wrangler cf op aside; do
  printf '%-14s %s\n' "$c" "$("$c" --version 2>/dev/null | head -1 || echo missing)"
done
