#!/usr/bin/env bash
#
# setup_ssh_from_1password.sh — rebuild the SSH + commit-signing setup on a new
# machine from keys already held in 1Password.
#
#   setup_ssh_from_1password.sh --check     verify only, change nothing
#   setup_ssh_from_1password.sh             create what is missing
#   setup_ssh_from_1password.sh --force     also overwrite protected configs
#
# What it does:
#   1. exports the five PUBLIC keys from 1Password to ~/.ssh/*.pub
#   2. builds ~/.ssh/allowed_signers from the two SIGNING keys
#   3. installs ~/.ssh/config and ~/.config/1Password/ssh/agent.toml
#   4. installs ~/.gitconfig{.local,-personal,-work} from templates
#
# It never touches private keys. Those stay in the vault and are served only by
# the 1Password SSH agent. Nothing here can write private key material.
#
# Prerequisites: 1Password app with the SSH agent enabled, and the op CLI with
# desktop-app integration turned on.

set -u

# file stem | vault | public-key comment | role | item title (defaults to stem)
KEYS=(
  "somto_auth_ed25519|Personal|smugeh@gmail.com|auth"
  "somto_sign_ed25519|Personal|smugeh@gmail.com|sign"
  "swissblock_auth_ed25519|Swissblock|smedua@swissblock.net|auth"
  "swissblock_sign_ed25519|Swissblock|smedua@swissblock.net|sign"
  "altschool_vm_rsa|Personal|altschool development host|auth|AltSchool VM SSH Key"
)

MODE=create
case "${1:-}" in
  --check) MODE=check ;;
  --force) MODE=force ;;
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  "") ;;
  *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[1;33m%s\033[0m\n' "$1"; }
hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# Resolve through the ~/bin symlink to find the repo.
SELF="$0"
while [ -L "$SELF" ]; do
  link="$(readlink "$SELF")"
  case "$link" in /*) SELF="$link" ;; *) SELF="$(dirname "$SELF")/$link" ;; esac
done
REPO="$(cd "$(dirname "$SELF")/.." && pwd)"
TPL="$REPO/templates"
AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

fail=0

hdr "Prerequisites"
if command -v op >/dev/null; then grn "  op CLI: $(op --version)"
else red "  op CLI missing — brew install --cask 1password-cli"; fail=1; fi
if [ -S "$AGENT_SOCK" ]; then grn "  1Password SSH agent: running"
else red "  1Password SSH agent NOT running — enable it in Settings > Developer > SSH agent"; fail=1; fi
if [ -x /Applications/1Password.app/Contents/MacOS/op-ssh-sign ]; then grn "  op-ssh-sign: present"
else red "  op-ssh-sign missing — is 1Password installed?"; fail=1; fi
if [ -d "$TPL" ]; then grn "  templates: $TPL"
else red "  templates not found at $TPL"; fail=1; fi
[ "$fail" -ne 0 ] && { echo; red "Prerequisites unmet. Nothing done."; exit 1; }

if op vault list >/dev/null 2>&1 </dev/null; then grn "  op can read vaults"
else red "  op cannot read vaults — enable CLI integration in 1Password (Settings > Developer)"; exit 1; fi

hdr "Public keys"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
for entry in "${KEYS[@]}"; do
  IFS='|' read -r name vault email role item <<< "$entry"
  item="${item:-$name}"
  target="$HOME/.ssh/$name.pub"
  pub="$(op read "op://$vault/$item/public key" </dev/null 2>/dev/null)"
  if [ -z "$pub" ]; then
    red "  ✗ $item — not found in vault '$vault'"; fail=1; continue
  fi
  want="$pub $email"
  if [ -f "$target" ] && [ "$(cat "$target")" = "$want" ]; then
    grn "  = $name.pub (current)"
  elif [ "$MODE" = check ]; then
    ylw "  ~ $name.pub would be written"
  else
    printf '%s\n' "$want" > "$target"; chmod 644 "$target"
    grn "  + $name.pub written"
  fi
done

hdr "allowed_signers"
signers=""
for entry in "${KEYS[@]}"; do
  IFS='|' read -r name vault email role item <<< "$entry"
  [ "$role" = sign ] || continue
  [ -f "$HOME/.ssh/$name.pub" ] || continue
  signers+="$email namespaces=\"git\" $(awk '{print $1" "$2}' "$HOME/.ssh/$name.pub")"$'\n'
done
if [ -z "$signers" ]; then
  red "  ✗ no signing keys available"
elif [ -f "$HOME/.ssh/allowed_signers" ] && [ "$(cat "$HOME/.ssh/allowed_signers")" = "$(printf '%s' "$signers")" ]; then
  grn "  = allowed_signers (current)"
elif [ "$MODE" = check ]; then
  ylw "  ~ allowed_signers would be written"
else
  printf '%s' "$signers" > "$HOME/.ssh/allowed_signers"; chmod 644 "$HOME/.ssh/allowed_signers"
  grn "  + allowed_signers written ($(printf '%s' "$signers" | wc -l | tr -d ' ') principals)"
fi

hdr "Config files from templates"
# dest | template | clobber-safe?
install_tpl() {
  local dest="$1" tpl="$2" protect="$3"
  [ -f "$TPL/$tpl" ] || { red "  ✗ missing template $tpl"; return; }
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    if cmp -s "$TPL/$tpl" "$dest"; then grn "  = ${dest/#$HOME/~} (matches template)"; return; fi
    if [ "$protect" = protect ] && [ "$MODE" != force ]; then
      ylw "  ! ${dest/#$HOME/~} exists and differs — left alone (use --force to overwrite)"; return
    fi
  fi
  if [ "$MODE" = check ]; then ylw "  ~ ${dest/#$HOME/~} would be written"; return; fi
  cp "$TPL/$tpl" "$dest"; grn "  + ${dest/#$HOME/~} installed"
}
install_tpl "$HOME/.ssh/config"                        ssh-config.template            protect
install_tpl "$HOME/.config/1Password/ssh/agent.toml"   1password-agent.toml.template  protect
install_tpl "$HOME/.gitconfig.local"                   gitconfig-local.template       protect
install_tpl "$HOME/.gitconfig-personal"                gitconfig-personal.template    protect
install_tpl "$HOME/.gitconfig-work"                    gitconfig-work.template        protect
chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
chmod 600 "$HOME"/.gitconfig.local "$HOME"/.gitconfig-personal "$HOME"/.gitconfig-work 2>/dev/null || true

hdr "Verification"
echo "  keys the agent serves:"
SSH_AUTH_SOCK="$AGENT_SOCK" ssh-add -l 2>/dev/null | awk '{print "    "$3}' || echo "    (none)"
echo "  no private key material in ~/.ssh:"
if grep -rl 'PRIVATE KEY' "$HOME/.ssh" 2>/dev/null; then red "    !! PRIVATE KEY ON DISK"; else grn "    ✓ confirmed"; fi

hdr "Remaining manual steps"
cat <<'EOF'
  1. Upload the four public keys to GitHub — the Key type dropdown matters:
       somto_auth_ed25519.pub       -> SomtoUgeh         Authentication key
       somto_sign_ed25519.pub       -> SomtoUgeh         Signing key
       swissblock_auth_ed25519.pub  -> somto-swissblock  Authentication key
       swissblock_sign_ed25519.pub  -> somto-swissblock  Signing key
     Copy with:  pbcopy < ~/.ssh/<name>.pub
  2. Enable Vigilant mode on both GitHub accounts.
  3. Sign a test commit under ~/code/work and ~/code/personal, approving the
     1Password prompt once per key:
       git commit --allow-empty -m "signing test" && git verify-commit HEAD
EOF
[ "$MODE" = check ] && { echo; ylw "(--check: nothing was changed)"; }
exit 0
