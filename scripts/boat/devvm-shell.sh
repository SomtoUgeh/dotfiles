#!/usr/bin/env bash
# zsh + starship on a project VM, the same as julds (install_cloud_dotfiles.sh),
# without its git config and GitHub key steps: project VMs keep their own key.
# Runs as `user` after link-agent-config (needs ~/code/personal/dotfiles). Idempotent.
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
D=$HOME/code/personal/dotfiles
[ -d "$D/shell" ] || { echo "devvm-shell: run link-agent-config first" >&2; exit 1; }

sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zsh fzf direnv eza >/dev/null

if ! command -v starship >/dev/null; then
  t=$(mktemp -d)
  curl -fsSL https://github.com/starship/starship/releases/download/v1.26.0/starship-x86_64-unknown-linux-gnu.tar.gz -o "$t/s.tar.gz"
  printf '%s  %s\n' 321f0dd7af8340a5f2e6a8fec6538a04f617486f9ec70d878f91c09cd8deef22 "$t/s.tar.gz" | sha256sum --check --status
  tar -xzf "$t/s.tar.gz" -C "$t"
  install -m 0755 "$t/starship" "$HOME/.local/bin/starship"
  rm -r "$t"
fi

pinned() { # <repo> <dir> <revision>
  [ -d "$2/.git" ] || git clone -q --filter=blob:none "$1" "$2"
  git -C "$2" fetch -q --depth=1 origin "$3"
  git -C "$2" checkout -q --detach "$3"
}
pinned https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" a5ecff7560b2e26f612032c632a12c75a3048bd0
C=$HOME/.oh-my-zsh/custom/plugins
pinned https://github.com/Aloxaf/fzf-tab.git "$C/fzf-tab" 24105b15714bfec37989ed5c5b6e60f572253019
pinned https://github.com/zsh-users/zsh-autosuggestions.git "$C/zsh-autosuggestions" 85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
pinned https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$C/fast-syntax-highlighting" 4672ad5dd9ad68a7effc1476d65afb7c584ce2b3

link() { # <source> <target>
  if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then return; fi
  if [ -e "$2" ] || [ -L "$2" ]; then mv "$2" "$2.backup.$(date +%Y%m%d_%H%M%S)"; fi
  mkdir -p "$(dirname "$2")"
  ln -s "$1" "$2"
}
link "$D/shell/.zshenv" "$HOME/.zshenv"
link "$D/shell/.zshrc.cloud" "$HOME/.zshrc"
link "$D/config/starship/starship.toml" "$HOME/.config/starship.toml"

# Machine-local additions that ~/.bashrc and ~/.profile hold for bash.
# .zshrc.private (sourced by .zshrc): the Playwright browsers in the base snapshot.
cat >"$HOME/.zshrc.private" <<'Z'
# Machine-local, written by devvm-shell.sh.
[ -d "$HOME/.local/share/ms-playwright" ] && export PLAYWRIGHT_BROWSERS_PATH="$HOME/.local/share/ms-playwright"
Z
# .zprofile (login shells only, so agent shells do not get it): the 1Password token.
cat >"$HOME/.zprofile" <<'Z'
# Machine-local, written by devvm-shell.sh.
if [ -r "$HOME/.config/op/service-account-token" ]; then
  chmod 700 "$HOME/.config/op"; chmod 600 "$HOME/.config/op/service-account-token"
  export OP_SERVICE_ACCOUNT_TOKEN="$(cat "$HOME/.config/op/service-account-token")"
fi
Z

# T3 starts agents from its systemd user service, which reads neither file, so
# give the user manager the Playwright path too (takes effect when T3 restarts).
if [ -d "$HOME/.local/share/ms-playwright" ]; then
  mkdir -p "$HOME/.config/environment.d"
  # shellcheck disable=SC2016 # environment.d expands ${HOME} itself
  printf 'PLAYWRIGHT_BROWSERS_PATH=${HOME}/.local/share/ms-playwright\n' >"$HOME/.config/environment.d/playwright.conf"
fi

sudo chsh -s "$(command -v zsh)" "$USER"
getent passwd "$USER" | cut -d: -f7
zsh -ic 'echo "zsh ok: starship $(starship --version | head -1 | cut -d" " -f2)"' 2>&1 | tail -1
