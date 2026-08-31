#!/usr/bin/env bash

set -euo pipefail

HOST="altschool"
AUTH=0
UPDATE=0
REPOSITORY=""

usage() {
  cat <<'EOF'
Usage: setup_altschool_cloud.sh [options]

Options:
  --host HOST         SSH host alias (default: altschool)
  --auth              Run interactive GitHub, Grok, and OpenCode login
  --update            Update Bun, Grok, and OpenCode after installation
  --repo OWNER/REPO   Clone a repository under ~/code/TalentQL
  -h, --help          Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:?--host requires a value}"
      shift 2
      ;;
    --auth)
      AUTH=1
      shift
      ;;
    --update)
      UPDATE=1
      shift
      ;;
    --repo)
      REPOSITORY="${2:?--repo requires OWNER/REPO}"
      shift 2
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

if [ -n "$REPOSITORY" ] &&
   [[ ! "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\.git)?$ ]]; then
  echo "Repository must use OWNER/REPO format: $REPOSITORY" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH=(ssh -o ClearAllForwardings=yes "$HOST")

run_interactive() {
  local quoted
  printf -v quoted '%q' "$1"
  ssh -t -o ClearAllForwardings=yes "$HOST" "bash -lic $quoted"
}

echo "Bootstrapping $HOST..."

"${SSH[@]}" bash -s -- "$UPDATE" <<'REMOTE'
set -euo pipefail

UPDATE="$1"

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this setup as the regular cloud user, not root." >&2
  exit 1
fi

if ! sudo -n true 2>/dev/null; then
  echo "The cloud user needs passwordless sudo for unattended setup." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  git \
  git-delta \
  git-lfs \
  gh \
  jq \
  openssh-client \
  ripgrep \
  rsync \
  tmux \
  unzip

install_script() {
  local url="$1"
  local installer
  installer="$(mktemp)"
  curl -fsSL "$url" -o "$installer"
  bash "$installer"
  rm -f "$installer"
}

node_needs_install=0
if ! command -v node >/dev/null 2>&1; then
  node_needs_install=1
else
  current_node_major="$(node --version | tr -d v | cut -d. -f1)"
  if [ "$current_node_major" -lt 22 ]; then
    node_needs_install=1
  fi
fi

if [ "$node_needs_install" = "1" ]; then
  nodesource_installer="$(mktemp)"
  curl -fsSL https://deb.nodesource.com/setup_22.x -o "$nodesource_installer"
  sudo -E bash "$nodesource_installer"
  rm -f "$nodesource_installer"
  sudo apt-get install -y nodejs
fi

node_major="$(node --version | tr -d v | cut -d. -f1)"
if [ "$node_major" -lt 22 ]; then
  echo "Node 22 or newer is required; found $(node --version)." >&2
  exit 1
fi

if [ ! -x "$HOME/.bun/bin/bun" ]; then
  install_script https://bun.sh/install
fi

if [ ! -x "$HOME/.grok/bin/grok" ]; then
  install_script https://x.ai/cli/install.sh
fi

if [ ! -x "$HOME/.opencode/bin/opencode" ]; then
  install_script https://opencode.ai/install
fi

mkdir -p "$HOME/.local/bin" "$HOME/code/TalentQL"
ln -sfn "$HOME/.bun/bin/bun" "$HOME/.local/bin/bun"
ln -sfn "$HOME/.bun/bin/bun" "$HOME/.local/bin/bunx"
ln -sfn "$HOME/.grok/bin/grok" "$HOME/.local/bin/grok"
ln -sfn "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"

if ! grep -Fq '$HOME/.local/bin' "$HOME/.profile"; then
  cat >>"$HOME/.profile" <<'PROFILE'

# Cloud development tools
export PATH="$HOME/.local/bin:$PATH"
PROFILE
fi

export PATH="$HOME/.local/bin:$PATH"

if [ "$UPDATE" = "1" ]; then
  bun upgrade
  grok update
  opencode upgrade
fi

if [ ! -f "$HOME/.gitconfig-personal" ]; then
  echo
  echo "Folder-driven Git identity is not installed yet."
  echo "After cloning dotfiles, run:"
  echo '  ~/code/personal/dotfiles/scripts/install_cloud_dotfiles.sh'
fi
REMOTE

if [ "$AUTH" = "1" ]; then
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "--auth requires a real terminal for device/browser approval." >&2
    exit 1
  fi

  echo
  echo "Authenticating GitHub..."
  run_interactive \
    'gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web'

  echo
  echo "Authenticating Grok..."
  run_interactive \
    'grok models 2>&1 | grep -q "You are logged in" || grok login --device-code'

  echo
  echo "Authenticating OpenCode with xAI..."
  # The single-quoted command must expand HOME on the remote host.
  # shellcheck disable=SC2016
  run_interactive \
    'auth_file="$HOME/.local/share/opencode/auth.json"; if [ -s "$auth_file" ] && jq -e "has(\"xai\")" "$auth_file" >/dev/null; then opencode auth list; else opencode auth login --provider xAI; fi'
fi

if [ -n "$REPOSITORY" ]; then
  echo
  echo "Cloning $REPOSITORY..."
  "${SSH[@]}" bash -s -- "$REPOSITORY" <<'REMOTE'
set -euo pipefail

repository="$1"
name="${repository##*/}"
name="${name%.git}"
target="$HOME/code/TalentQL/$name"

if [ -d "$target/.git" ]; then
  echo "Repository already exists: $target"
elif [ -e "$target" ]; then
  echo "Target exists but is not a Git repository: $target" >&2
  exit 1
else
  gh repo clone "$repository" "$target"
fi

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
if [ -f "$target/bun.lock" ]; then
  (cd "$target" && bun install --frozen-lockfile)
fi

if [ -f "$target/apps/degree-admin/prisma/schema.prisma" ]; then
  (cd "$target/apps/degree-admin" && bunx --bun prisma generate)
fi
REMOTE
fi

verify_args=(--host "$HOST")
if [ "$AUTH" = "1" ]; then
  verify_args+=(--require-auth)
fi
"$SCRIPT_DIR/verify_altschool_cloud.sh" "${verify_args[@]}"

echo
echo "Setup complete for $HOST."
