#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname -s)" != "Linux" ] || ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer supports Ubuntu Linux only." >&2
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ]; then
  echo "This installer supports Ubuntu Linux only." >&2
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this installer as the regular cloud user, not root." >&2
  exit 1
fi

if ! sudo -n true 2>/dev/null; then
  echo "Passwordless sudo is required for unattended package setup." >&2
  exit 1
fi

SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
  link=$(readlink "$SELF")
  case "$link" in /*) SELF="$link" ;; *) SELF="$(dirname "$SELF")/$link" ;; esac
done
DOTFILES_DIR="$(cd "$(dirname "$SELF")/.." && pwd)"
timestamp="$(date +%Y%m%d_%H%M%S)"

link_path() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    mv "$target" "$target.backup.$timestamp"
  fi

  ln -s "$source" "$target"
}

seed_git_identity_file() {
  local source="$1"
  local target="$2"

  if [ -e "$target" ] || [ -L "$target" ]; then
    return
  fi

  if [ ! -f "$source" ]; then
    echo "Missing git identity template: $source" >&2
    exit 1
  fi

  cp "$source" "$target"
  chmod 0644 "$target"
}

add_github_ssh_key() {
  local pub="$1"
  local title="$2"
  local type="$3"
  local output=""

  if output="$(gh ssh-key add "$pub" --title "$title" --type "$type" 2>&1)"; then
    echo "$output"
    return 0
  fi

  if printf '%s' "$output" | grep -qiE 'already in use|already exists|duplicate'; then
    echo "GitHub already has $type key '$title'"
    return 0
  fi

  printf '%s\n' "$output" >&2
  return 1
}

setup_personal_github_ssh() {
  local key="$HOME/.ssh/id_ed25519_personal"
  local pub="$key.pub"
  local email="smugeh@gmail.com"
  local title="altschool-dev"
  local personal_config="$HOME/.gitconfig-personal"
  local ssh_config="$HOME/.ssh/config"
  local allowed="$HOME/.ssh/allowed_signers"
  local pub_line=""

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [ ! -f "$key" ]; then
    ssh-keygen -t ed25519 -f "$key" -C "$title SomtoUgeh" -N ""
  fi
  chmod 600 "$key"
  chmod 644 "$pub"

  if [ ! -f "$ssh_config" ] || ! grep -q '^Host github.com' "$ssh_config"; then
    cat "$DOTFILES_DIR/templates/ssh-config-cloud.template" >>"$ssh_config"
    chmod 600 "$ssh_config"
  fi

  # Change only the cloud identity/signing fields, preserving unrelated options.
  if [ -f "$personal_config" ]; then
    cp -p "$personal_config" "$personal_config.backup.$timestamp" || return 1
    if [ -L "$personal_config" ]; then
      rm "$personal_config" || return 1
      cp -p "$personal_config.backup.$timestamp" "$personal_config" || return 1
    fi
  fi
  git config -f "$personal_config" user.name 'Somto Odera' || return 1
  git config -f "$personal_config" user.email "$email" || return 1
  git config -f "$personal_config" user.signingkey "$key" || return 1
  git config -f "$personal_config" gpg.format ssh || return 1
  git config -f "$personal_config" gpg.ssh.program ssh-keygen || return 1
  git config -f "$personal_config" gpg.ssh.allowedSignersFile "$allowed" || return 1
  git config -f "$personal_config" commit.gpgsign true || return 1
  git config -f "$personal_config" tag.gpgSign true || return 1
  git config -f "$personal_config" core.sshCommand "ssh -i $key -o IdentitiesOnly=yes" || return 1
  chmod 600 "$personal_config"

  pub_line="$(awk '{print $1, $2}' "$pub")"
  touch "$allowed"
  chmod 600 "$allowed"
  if ! grep -Fq "$pub_line" "$allowed"; then
    printf '%s %s\n' "$email" "$pub_line" >>"$allowed"
  fi

  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated; skipping SSH key upload."
    echo "After 'gh auth login', re-run this installer or add both key types:"
    echo "  gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key"
    echo "  gh ssh-key add $pub --title '$title' --type authentication"
    echo "  gh ssh-key add $pub --title '$title signing' --type signing"
    return 0
  fi

  gh config set git_protocol ssh >/dev/null

  if ! add_github_ssh_key "$pub" "$title" authentication; then
    echo "Could not upload the authentication key. Grant scopes and retry:" >&2
    echo "  gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key" >&2
    return 0
  fi
  if ! add_github_ssh_key "$pub" "$title signing" signing; then
    echo "Could not upload the signing key. Grant scopes and retry:" >&2
    echo "  gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key" >&2
    return 0
  fi
}

install_pinned_repository() {
  local repository="$1"
  local target="$2"
  local revision="$3"

  if [ ! -d "$target/.git" ]; then
    git clone --filter=blob:none "$repository" "$target"
  fi

  git -C "$target" fetch --depth=1 origin "$revision"
  git -C "$target" checkout --detach "$revision"
}

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
  bat \
  direnv \
  fd-find \
  fzf \
  git-delta \
  git-lfs \
  python3 \
  shellcheck \
  tree \
  zsh

if apt-cache show eza >/dev/null 2>&1; then
  sudo apt-get install -y eza
fi

mkdir -p "$HOME/.local/bin" "$HOME/code/personal"
ln -sfn /usr/bin/batcat "$HOME/.local/bin/bat"
ln -sfn /usr/bin/fdfind "$HOME/.local/bin/fd"

if ! command -v starship >/dev/null 2>&1; then
  starship_dir="$(mktemp -d)"
  curl -fsSL \
    https://github.com/starship/starship/releases/download/v1.26.0/starship-x86_64-unknown-linux-gnu.tar.gz \
    -o "$starship_dir/starship.tar.gz"
  printf '%s  %s\n' \
    321f0dd7af8340a5f2e6a8fec6538a04f617486f9ec70d878f91c09cd8deef22 \
    "$starship_dir/starship.tar.gz" | sha256sum --check --status
  tar -xzf "$starship_dir/starship.tar.gz" -C "$starship_dir"
  install -m 0755 "$starship_dir/starship" "$HOME/.local/bin/starship"
  rm -rf "$starship_dir"
fi

if ! command -v uv >/dev/null 2>&1; then
  uv_dir="$(mktemp -d)"
  curl -fsSL \
    https://github.com/astral-sh/uv/releases/download/0.12.7/uv-x86_64-unknown-linux-gnu.tar.gz \
    -o "$uv_dir/uv.tar.gz"
  printf '%s  %s\n' \
    788f18abea7c5f55d6216e4f5613fd89d4d59b631efeec117b2b07fe72f1da21 \
    "$uv_dir/uv.tar.gz" | sha256sum --check --status
  tar -xzf "$uv_dir/uv.tar.gz" -C "$uv_dir"
  install -m 0755 "$uv_dir/uv-x86_64-unknown-linux-gnu/uv" "$HOME/.local/bin/uv"
  install -m 0755 "$uv_dir/uv-x86_64-unknown-linux-gnu/uvx" "$HOME/.local/bin/uvx"
  rm -rf "$uv_dir"
fi

if ! command -v pnpm >/dev/null 2>&1; then
  "$HOME/.bun/bin/bun" add --global pnpm@11.24.0
fi

if ! command -v ast-grep >/dev/null 2>&1; then
  "$HOME/.bun/bin/bun" add --global @ast-grep/cli@0.45.3
fi

install_pinned_repository \
  https://github.com/ohmyzsh/ohmyzsh.git \
  "$HOME/.oh-my-zsh" \
  a5ecff7560b2e26f612032c632a12c75a3048bd0
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
install_pinned_repository \
  https://github.com/Aloxaf/fzf-tab.git \
  "$ZSH_CUSTOM/plugins/fzf-tab" \
  24105b15714bfec37989ed5c5b6e60f572253019
install_pinned_repository \
  https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
  85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
install_pinned_repository \
  https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
  "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" \
  4672ad5dd9ad68a7effc1476d65afb7c584ce2b3

link_path "$DOTFILES_DIR/shell/.zshenv" "$HOME/.zshenv"
link_path "$DOTFILES_DIR/shell/.zshrc.cloud" "$HOME/.zshrc"
link_path "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"
link_path "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
link_path "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"
# Manual scanners only: no global Git hooks or scheduled monitoring.
for script_name in scan_repo.sh scan_remote.sh; do
  link_path "$DOTFILES_DIR/scripts/$script_name" "$HOME/.local/bin/$script_name"
done
if [ -L "$HOME/.git-hooks" ] && [ "$(readlink "$HOME/.git-hooks")" = "$DOTFILES_DIR/git/hooks" ]; then
  rm "$HOME/.git-hooks"
fi

seed_git_identity_file \
  "$DOTFILES_DIR/templates/gitconfig-local.template" \
  "$HOME/.gitconfig.local"
# Call directly so errexit remains active for local key/configuration failures.
setup_personal_github_ssh

link_path "$DOTFILES_DIR/agents/skills" "$HOME/.agents/skills"
link_path "$DOTFILES_DIR/agents/skills" "$HOME/.grok/skills"
link_path "$DOTFILES_DIR/agents/shared/AGENTS.md" "$HOME/.grok/AGENTS.md"
link_path "$DOTFILES_DIR/agents/opencode/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
link_path "$DOTFILES_DIR/agents/shared/ETHOS.md" "$HOME/.config/opencode/ETHOS.md"
link_path "$DOTFILES_DIR/agents/opencode/opencode.cloud.jsonc" "$HOME/.config/opencode/opencode.jsonc"
# OpenCode 2 config, agents, commands, skills, and hook plugins.
# V1 leftover npm plugin installs in the config directory are not used.
rm -rf "$HOME/.config/opencode/node_modules"
rm -f "$HOME/.config/opencode/package.json" \
  "$HOME/.config/opencode/package-lock.json" \
  "$HOME/.config/opencode/bun.lock" \
  "$HOME/.config/opencode/.gitignore"
# V1 discovered `plugin/` (singular). Keep only the V2 `plugins/` directory.
if [ -e "$HOME/.config/opencode/plugin" ] || [ -L "$HOME/.config/opencode/plugin" ]; then
  mv "$HOME/.config/opencode/plugin" "$HOME/.config/opencode/plugin.backup.$timestamp"
fi
link_path "$DOTFILES_DIR/agents/opencode/agents" "$HOME/.config/opencode/agents"
link_path "$DOTFILES_DIR/agents/opencode/commands" "$HOME/.config/opencode/commands"
link_path "$DOTFILES_DIR/agents/skills" "$HOME/.config/opencode/skills"
# Linux inotify cannot watch a plugins directory that is itself a symlink.
if [ -L "$HOME/.config/opencode/plugins" ]; then
  rm "$HOME/.config/opencode/plugins"
fi
mkdir -p "$HOME/.config/opencode/plugins"
for plugin in "$DOTFILES_DIR/agents/opencode/plugins/"*.js; do
  [ -e "$plugin" ] || continue
  link_path "$plugin" "$HOME/.config/opencode/plugins/$(basename "$plugin")"
done

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.grok/bin:$HOME/.opencode/bin:$PATH"

for name in plan context7 cloudflare-docs agentation shadcn; do
  grok mcp remove "$name" >/dev/null 2>&1 || true
done
grok mcp add --transport http context7 https://mcp.context7.com/mcp
grok mcp add --transport http cloudflare-docs https://docs.mcp.cloudflare.com/mcp
grok mcp add shadcn -- npx -y shadcn@4.19.1 mcp

sudo chsh -s "$(command -v zsh)" "$USER"

echo
echo "Cloud dotfiles installed from $DOTFILES_DIR"
echo "Start a new SSH session to use Zsh and Starship."
