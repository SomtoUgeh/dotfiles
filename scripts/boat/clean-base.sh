#!/usr/bin/env bash
# Strip a project VM's machine identity before saving it as a <project>-base snapshot.
# Run on a throwaway machine started from the VM's snapshot, never on the VM itself:
#   boat new --from <snapshot> --environment <p> --type <size> --name <p>-base-rebuild --ttl 3600
#   cat clean-base.sh | boat ssh <id> -- bash -s -- <p>
#   boat snapshot <id> <p>-base && boat delete <id> --yes
# Why: a base copied from a live VM keeps its Tailscale node key, T3 server and keepalive.
# Every boat-check machine then joins the tailnet as that VM, steals its address and runs
# a second T3 server, so T3 times out against the real VM (erivault, 12 Nov 2026).
# Do not run `tailscale logout` here: the node key is shared with the live VM and logout revokes it.
set -euo pipefail
P=${1:?usage: clean-base.sh <project>}
export XDG_RUNTIME_DIR=/run/user/$(id -u)
sudo systemctl disable --now "$P-keepalive.timer" tailscaled 2>/dev/null || true
sudo rm -rf /var/lib/tailscale/tailscaled.state /var/lib/tailscale/certs /var/lib/tailscale/files
systemctl --user disable --now t3code.service agent-config-sync.timer 2>/dev/null || true
rm -f ~/.aside/cli/auth.json ~/.claude/.credentials.json ~/.ssh/id_ed25519_"$P" ~/.ssh/id_ed25519_"$P".pub
sudo systemctl disable "$P-hostname.service" 2>/dev/null || true
sudo hostnamectl set-hostname "$P-check"
echo "clean-base: tailscaled $(systemctl is-enabled tailscaled 2>&1), t3code $(systemctl --user is-enabled t3code.service 2>&1), hostname $(hostname)"
