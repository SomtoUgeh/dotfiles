#!/usr/bin/env bash
# Project VM setup. Usage from the Mac:
#   boat ssh <id> -- bash -s -- altschool code/TalentQL/altschool-web-platforms "'bun install --frozen-lockfile'" < devvm-setup.sh
# (the install command needs the extra single quotes: boat ssh joins arguments into one remote command line)
# Runs as `user` over boat ssh. Idempotent.
set -euo pipefail
P=$1 REPO_PATH=$2 INSTALL=$3
export PATH=$HOME/.bun/bin:$HOME/.local/bin:$PATH

echo "== hostname $P (boat does not snapshot /etc/hostname)"
sudo tee /etc/systemd/system/$P-hostname.service >/dev/null <<U
[Unit]
Description=Keep the hostname "$P" (boat does not snapshot /etc/hostname)
Before=network-pre.target
[Service]
Type=oneshot
ExecStart=/usr/bin/hostnamectl set-hostname $P
ExecStart=/bin/sh -c 'grep -q "[[:space:]]$P\$" /etc/hosts || echo "127.0.1.1 $P" >> /etc/hosts'
[Install]
WantedBy=multi-user.target
U
sudo systemctl daemon-reload
sudo systemctl enable --now $P-hostname.service
hostname

echo "== tailscale"
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1
sudo systemctl enable --now tailscaled
# Lets `user` run `tailscale serve` (t3 pair --tailscale) without root, as on julds.
sudo tailscale set --operator=user
tailscale version | head -1
# After this script: `sudo tailscale up --hostname=<project>` (Somto opens the login link),
# then `t3 pair --tailscale --ttl 1h` and paste the pairing link into the T3 app.

echo "== T3 (nightly train, same as julds)"
command -v t3 >/dev/null || curl -fsSL https://t3.codes/install.sh | T3CODE_CHANNEL=nightly sh 2>&1 | tail -3
t3 --version
sudo loginctl enable-linger user
XDG_RUNTIME_DIR=/run/user/$(id -u); export XDG_RUNTIME_DIR
t3 service install 2>&1 | tail -5
# julds fix from 27 Oct 2026: start T3 from its activeVersion, so self-updates that
# prune old versions never leave the unit pointing at a deleted binary.
cat > ~/.local/bin/t3-service-launcher <<'L'
#!/usr/bin/env bash
# Start the T3 service launcher from T3's current activeVersion, not a pinned version.
R="$HOME/.t3/runtime"
v=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["activeVersion"])' "$R/service-state.json" 2>/dev/null)
bin="$R/versions/$v/t3"
if [ -z "$v" ] || [ ! -x "$bin" ]; then
  bin=$(ls -1d "$R"/versions/*/t3 2>/dev/null | sort -V | tail -1)
fi
[ -x "$bin" ] || { echo "t3-service-launcher: no T3 runtime found under $R/versions" >&2; exit 1; }
ln -sfn "$bin" "$HOME/.local/bin/t3"
exec "$bin" __service-launcher "$@"
L
chmod +x ~/.local/bin/t3-service-launcher
mkdir -p ~/.config/systemd/user/t3code.service.d
printf '[Service]\nExecStart=\nExecStart=%%h/.local/bin/t3-service-launcher\n' > ~/.config/systemd/user/t3code.service.d/stable-launcher.conf
systemctl --user daemon-reload
systemctl --user restart t3code.service
t3 service protect --yes 2>&1 | tail -3 || true
sleep 3; systemctl --user is-active t3code.service

echo "== keepalive timer (julds pattern, no portless)"
sudo tee /usr/local/sbin/$P-keepalive >/dev/null <<K
#!/bin/sh
# Keeps $P reachable after a boat resume: /home/user is hydrated lazily, so the
# user systemd manager can start before its unit files exist and never start T3.
systemctl is-active --quiet tailscaled || systemctl start tailscaled
U="runuser -u user -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user"
[ -f /home/user/.config/systemd/user/t3code.service ] || exit 0
if ! \$U is-active --quiet t3code.service; then
  \$U daemon-reload
  \$U start t3code.service
  \$U start agent-config-sync.timer 2>/dev/null
  logger -t $P-keepalive "started t3code after it was found inactive"
fi
K
sudo chmod 755 /usr/local/sbin/$P-keepalive
sudo tee /etc/systemd/system/$P-keepalive.service >/dev/null <<K
[Unit]
Description=Keep Tailscale and T3 running on $P
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/$P-keepalive
K
sudo tee /etc/systemd/system/$P-keepalive.timer >/dev/null <<K
[Unit]
Description=Check Tailscale and T3 every minute
[Timer]
OnBootSec=30
OnUnitActiveSec=60
[Install]
WantedBy=timers.target
K
sudo systemctl daemon-reload
sudo systemctl enable --now $P-keepalive.timer
systemctl is-active $P-keepalive.timer

echo "== ~/.boatignore (worktree deps and build output; the main clone keeps node_modules)"
{
  echo '# Rebuildable caches and worktree output: left out of snapshots (7 Nov 2026).'
  echo '.npm/'
  echo '.bun/install/cache/'
  for d in node_modules dist .turbo .next .wrangler .output coverage playwright-report test-results; do
    echo "/.t3/worktrees/**/$d/"
  done
} > ~/.boatignore

echo "== git identity and a per-VM SSH key (GitHub access and commit signing)"
[ -f ~/.ssh/id_ed25519_$P ] || ssh-keygen -q -t ed25519 -N '' -C "somto@$P.boat" -f ~/.ssh/id_ed25519_$P
echo "smugeh@gmail.com $(cat ~/.ssh/id_ed25519_$P.pub)" > ~/.ssh/allowed_signers
git config --global user.name "Somto Odera"
git config --global user.email smugeh@gmail.com
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_$P
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
git config --global commit.gpgsign true
git config --global tag.gpgSign true
git config --global core.sshCommand "ssh -i ~/.ssh/id_ed25519_$P -o IdentitiesOnly=yes"
ssh-keyscan -t ed25519 github.com 2>/dev/null >> ~/.ssh/known_hosts
sort -u -o ~/.ssh/known_hosts ~/.ssh/known_hosts

echo "== boat-check config"
printf 'BOAT_CHECK_PROJECT=%q\nBOAT_CHECK_SNAPSHOT=%q\nBOAT_CHECK_ENVIRONMENT=%q\nBOAT_CHECK_REPO_PATH=%q\nBOAT_CHECK_INSTALL=%q\n' \
  "$P" "$P-base" "$P" "$REPO_PATH" "$INSTALL" | sudo tee /etc/boat-check.env >/dev/null
cat /etc/boat-check.env

# Next, once this VM's key is on GitHub: install link-agent-config.sh as
# ~/.local/bin/link-agent-config and run it (see README).

echo "== boat docs MCP for Claude"
claude mcp add --transport http boat-docs --scope user https://docs.boat.dev/mcp 2>&1 | tail -1 || true

echo "== done"; free -m | head -2
