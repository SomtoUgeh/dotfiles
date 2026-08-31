#!/usr/bin/env bash

set -euo pipefail

HOST="altschool"
REQUIRE_AUTH=0
SMOKE=0

usage() {
  cat <<'EOF'
Usage: verify_altschool_cloud.sh [options]

Options:
  --host HOST       SSH host alias (default: altschool)
  --require-auth    Fail if GitHub, Grok, or OpenCode is unauthenticated
  --smoke           Make one live Grok and OpenCode model request
  -h, --help        Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:?--host requires a value}"
      shift 2
      ;;
    --require-auth)
      REQUIRE_AUTH=1
      shift
      ;;
    --smoke)
      REQUIRE_AUTH=1
      SMOKE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$HOST" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Invalid SSH host alias: $HOST" >&2
  exit 2
fi

echo "Verifying $HOST..."

ssh -o ClearAllForwardings=yes "$HOST" bash -s -- "$REQUIRE_AUTH" "$SMOKE" <<'REMOTE'
set -euo pipefail

REQUIRE_AUTH="$1"
SMOKE="$2"
failures=0
warnings=0

ok() {
  echo "[ok] $1"
}

warn() {
  echo "[warn] $1"
  warnings=$((warnings + 1))
}

fail() {
  echo "[fail] $1" >&2
  failures=$((failures + 1))
}

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.grok/bin:$HOME/.opencode/bin:$PATH"

if [ "$(hostname)" = "altschool-dev" ] && [ "$(id -un)" = "altschool" ]; then
  ok "SSH identity is altschool@altschool-dev"
else
  fail "Unexpected SSH identity: $(id -un)@$(hostname)"
fi

for tool in git gh delta git-lfs node npm bun grok opencode gcc g++ make jq rg tmux; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool: $(command -v "$tool")"
  else
    fail "$tool is missing from PATH"
  fi
done

node_major="$(node --version | tr -d v | cut -d. -f1)"
if [ "$node_major" -ge 22 ]; then
  ok "Node $(node --version)"
else
  fail "Node 22 or newer is required; found $(node --version)"
fi

ok "Bun $(bun --version)"
ok "Grok $(grok --version | sed -n '1p')"
ok "OpenCode $(opencode --version)"

if systemctl is-active --quiet cloudflared && systemctl is-enabled --quiet cloudflared; then
  ok "cloudflared is active and enabled"
else
  fail "cloudflared is not active and enabled"
fi

sshd_t="$(sudo sshd -T)"
expect_sshd() {
  local key="$1"
  local value="$2"
  local actual
  actual="$(printf '%s\n' "$sshd_t" | awk -v k="$key" '$1 == k { print $2; exit }')"
  if [ "$actual" = "$value" ]; then
    ok "sshd $key $value"
  else
    fail "sshd $key is ${actual:-unset}; expected $value"
  fi
}

expect_sshd permitrootlogin no
expect_sshd passwordauthentication no
expect_sshd kbdinteractiveauthentication no
expect_sshd pubkeyauthentication yes
expect_sshd authenticationmethods publickey
expect_sshd allowagentforwarding no
expect_sshd allowtcpforwarding local
expect_sshd gatewayports no
expect_sshd x11forwarding no
expect_sshd permittunnel no

if [ -f /etc/ssh/sshd_config.d/99-cloud-development.conf ]; then
  ok "sshd drop-in 99-cloud-development.conf exists"
else
  fail "missing /etc/ssh/sshd_config.d/99-cloud-development.conf"
fi

ufw_status="$(sudo ufw status)"
if printf '%s\n' "$ufw_status" | grep -q '^Status: active'; then
  ok "UFW is active"
else
  fail "UFW is not active"
fi
if printf '%s\n' "$ufw_status" | grep -Eq '(^|[[:space:]])80/tcp|(^|[[:space:]])443/tcp'; then
  fail "UFW allows HTTP or HTTPS inbound"
else
  ok "UFW does not allow HTTP or HTTPS inbound"
fi
if systemctl is-active --quiet fail2ban && systemctl is-enabled --quiet fail2ban; then
  ok "fail2ban is active and enabled"
else
  fail "fail2ban is not active and enabled"
fi

available_kb="$(awk '/MemAvailable:/ { print $2 }' /proc/meminfo)"
if [ "$available_kb" -ge 2097152 ]; then
  ok "At least 2 GiB RAM is available"
else
  fail "Less than 2 GiB RAM is available"
fi

available_blocks="$(df -Pk "$HOME" | awk 'NR == 2 { print $4 }')"
if [ "$available_blocks" -ge 10485760 ]; then
  ok "At least 10 GiB disk space is available"
else
  fail "Less than 10 GiB disk space is available"
fi

if swapon --show --noheadings | grep -q .; then
  ok "Swap is configured"
else
  warn "No swap is configured"
fi

if gh auth status >/dev/null 2>&1; then
  ok "GitHub CLI is authenticated"
else
  if [ "$REQUIRE_AUTH" = "1" ]; then
    fail "GitHub CLI is not authenticated"
  else
    warn "GitHub CLI is not authenticated"
  fi
fi

grok_status="$(grok models 2>&1 || true)"
if printf '%s' "$grok_status" | grep -q "You are logged in"; then
  ok "Grok is authenticated"
else
  if [ "$REQUIRE_AUTH" = "1" ]; then
    fail "Grok is not authenticated"
  else
    warn "Grok is not authenticated"
  fi
fi

opencode_auth="$HOME/.local/share/opencode/auth.json"
if [ -s "$opencode_auth" ] && jq -e 'type == "object" and length > 0' "$opencode_auth" >/dev/null; then
  ok "OpenCode has provider credentials"
else
  if [ "$REQUIRE_AUTH" = "1" ]; then
    fail "OpenCode has no provider credentials"
  else
    warn "OpenCode has no provider credentials"
  fi
fi

gitconfig_link="$(readlink "$HOME/.gitconfig" 2>/dev/null || true)"
if [ -L "$HOME/.gitconfig" ] && [ -f "$HOME/.gitconfig" ] &&
   [[ "$gitconfig_link" == */git/.gitconfig ]]; then
  ok "Gitconfig is linked to the dotfiles git folder"
else
  fail "Gitconfig is not linked to the dotfiles git folder"
fi

if [ -L "$HOME/.gitignore_global" ] && [ -f "$HOME/.gitignore_global" ]; then
  ok "Global gitignore is linked"
else
  fail "Global gitignore is not linked"
fi

if [ -f "$HOME/.gitconfig.local" ] && [ -f "$HOME/.gitconfig-personal" ]; then
  ok "Folder-driven Git identity files exist"
else
  fail "Missing ~/.gitconfig.local or ~/.gitconfig-personal"
fi

expected_email="smugeh@gmail.com"
check_repo_identity() {
  local repo="$1"
  local email=""
  if [ ! -d "$repo/.git" ]; then
    warn "No Git repository at $repo"
    return
  fi
  email="$(git -C "$repo" config --get user.email || true)"
  if [ "$email" = "$expected_email" ]; then
    ok "Git identity in $repo is $email"
  else
    fail "Git identity in $repo is ${email:-unset}; expected $expected_email"
  fi
}

check_repo_identity "$HOME/code/personal/dotfiles"
check_repo_identity "$HOME/code/TalentQL/altschool-web-platforms"

if [ -f "$HOME/.ssh/id_ed25519_personal" ] && [ -f "$HOME/.ssh/id_ed25519_personal.pub" ]; then
  ok "Personal GitHub SSH key exists"
else
  fail "Missing ~/.ssh/id_ed25519_personal"
fi

if git -C "$HOME/code/personal/dotfiles" config --bool --get commit.gpgsign 2>/dev/null | grep -qx true &&
   git -C "$HOME/code/TalentQL/altschool-web-platforms" config --bool --get commit.gpgsign 2>/dev/null | grep -qx true; then
  ok "Personal commit signing is enabled for cloud checkouts"
else
  fail "commit.gpgsign is not enabled in personal/TalentQL checkouts"
fi

ssh_github="$(ssh -n -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
if printf '%s' "$ssh_github" | grep -q "successfully authenticated"; then
  ok "GitHub SSH authentication succeeded"
else
  fail "GitHub SSH authentication failed"
fi

sign_dir="$(mktemp -d "$HOME/code/personal/.git-sign-check.XXXXXX")"
if git -C "$sign_dir" init -q &&
   git -C "$sign_dir" commit --allow-empty -q -m "signing check" &&
   git -C "$sign_dir" verify-commit HEAD >/dev/null 2>&1; then
  ok "SSH commit signatures verify locally"
else
  fail "Could not create or verify an SSH-signed commit"
fi
rm -rf "$sign_dir"

if [ "$SMOKE" = "1" ] && [ "$failures" -eq 0 ]; then
  grok_reply="$(grok -p 'Reply exactly: GROK_OK' --max-turns 1 --output-format plain)"
  if printf '%s' "$grok_reply" | grep -q "GROK_OK"; then
    ok "Grok live request succeeded"
  else
    fail "Grok live request returned an unexpected response"
  fi

  opencode_reply="$(opencode run -m xai/grok-4.6 'Reply exactly: OPENCODE_OK')"
  if printf '%s' "$opencode_reply" | grep -q "OPENCODE_OK"; then
    ok "OpenCode live request succeeded"
  else
    fail "OpenCode live request returned an unexpected response"
  fi
fi

echo
echo "Verification finished with $failures failure(s) and $warnings warning(s)."
if [ "$failures" -gt 0 ]; then
  exit 1
fi
REMOTE
